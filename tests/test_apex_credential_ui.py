"""Credential form boundary tests; native APEX debug redaction is a separate gate."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "apex/application/pages/p00900-deployment-setup.apx"
FIELDS = {"P900_OCI_USER": 256, "P900_OCI_TENANCY": 256,
          "P900_OCI_FINGERPRINT": 47, "P900_OCI_PRIVATE_KEY": 4000}


def component(source, declaration):
    return source.split(declaration+" (\n", 1)[1].split("\n  )", 1)[0]


class CredentialFormTests(unittest.TestCase):
    def test_sensitive_items_use_native_nonpersistent_password_boundaries(self):
        source = PAGE.read_text(encoding="utf-8")
        for name, limit in FIELDS.items():
            item = component(source, "pageItem "+name)
            for expected in ("type: password", "storage: request", "encryptSessionState: true",
                             "authorizationScheme: @deployment-installer",
                             "sessionStateProtection: checksumRequiredSessionLevel",
                             "submitWhenEnterPressed: false", "used: always", "type: null",
                             'autocomplete="off"', "warnOnUnsavedChanges: ignore",
                             "maxLength: "+str(limit)):
                self.assertIn(expected, item, name)
            self.assertNotIn("default {", item)
            self.assertNotIn("staticValue:", item)
            self.assertNotIn("&"+name, source)
            # The native26.1.6 Password compiler rejects escapeSpecialChars;
            # the generated generic item inventory incorrectly includes it.
            security = re.search(r"security\s*\{(.*?)\n\s*\}", item, re.S).group(1)
            self.assertEqual(set(re.findall(r"^\s*(\w+):", security, re.M)), {
                "sessionStateProtection", "authorizationScheme", "encryptSessionState"})
        header = source.split("region introduction (", 1)[0]
        self.assertIn("pageAccessProtection: argumentsMustHaveChecksum", header)
        self.assertIn("formAutoComplete: false", header)
        self.assertIn("reloadOnSubmit: always", header)
        self.assertIn("enableDuplicatePageSubmissions: false", header)
        self.assertIn("warnOnUnsavedChanges: true", header)
        self.assertEqual(source.count("warnOnUnsavedChanges: ignore"), len(FIELDS))
        for name in ("P900_REGION", "P900_COMPARTMENT", "P900_MODEL"):
            self.assertNotIn("warnOnUnsavedChanges: ignore", component(source, "pageItem "+name))

    def test_native_creation_isolated_and_scrubs_success_error_and_render(self):
        source = PAGE.read_text(encoding="utf-8")
        action = component(source, "process create-local-oci-credential")
        self.assertIn("authorizationScheme: @deployment-installer", action)
        self.assertIn("value: CREATE_OCI_CREDENTIAL", action)
        self.assertIn("point: processing", action)
        self.assertIn("NVL(OWA_UTIL.GET_CGI_ENV('REQUEST_METHOD'),'UNSET')<>'POST'", action)
        for name in FIELDS:
            self.assertIn(":"+name+":=NULL", action)
        self.assertEqual(action.count("clear_inputs;"), 2)
        self.assertNotRegex(action, r"SQLERRM|DBMS_OUTPUT|apex_debug|JSON_OBJECT|\.to_clob")
        self.assertNotIn("GENERATE", action)
        self.assertNotIn("test_model(", action)
        self.assertNotIn("configure_profile(", action)
        self.assertIn("kcv_deploy.create_oci_credential(", action)
        render = component(source, "process read-setup-readiness")
        for name in FIELDS:
            self.assertLess(render.index(":"+name+":=NULL"), render.index("doc:=kcv_deploy.status_json"))
        normal = component(source, "process run-requested-setup-action")
        self.assertNotIn("CREATE_OCI_CREDENTIAL", normal)
        self.assertNotIn("P900_OCI_", normal)

    @unittest.skipUnless(shutil.which("node"), "Node is required for the cleanup behavior test")
    def test_browser_cleanup_keeps_only_explicit_creation_values_until_submission(self):
        source = PAGE.read_text(encoding="utf-8")
        fence = chr(96)*3
        code = re.search(r"executeWhenPageLoads:\s*"+fence+r"javascript\n(.*?)\n\s*"+fence, source, re.S).group(1)
        harness = r"""
const vm = require('vm'), assert = require('assert');
const names = __NAMES__, handlers = {}, windowHandlers = {};
const inputs = Object.fromEntries(names.map(id => [id, {
 value:'SYNTHETIC_CANARY', defaultValue:'SYNTHETIC_DEFAULT', valueAttribute:'SYNTHETIC_ATTRIBUTE', type:'password',
 removeAttribute(name){assert.strictEqual(name,'value');this.valueAttribute=null;}
}]));
const forbid = () => { throw Error('Credential cleanup must not log, persist or send input'); };
const context = {
 document:{getElementById:id=>inputs[id]},
 apex:{jQuery:()=>({on:(name,handler)=>{handlers[name]=handler;}})},
 window:{addEventListener:(name,handler)=>{windowHandlers[name]=handler;}},
 console:{log:forbid,error:forbid,debug:forbid},fetch:forbid,
 localStorage:{setItem:forbid},sessionStorage:{setItem:forbid}
};
vm.runInNewContext(__CODE__, context);
const cleared=()=>names.every(id=>inputs[id].value==='' && inputs[id].defaultValue==='' && inputs[id].valueAttribute===null);
const fill=()=>names.forEach(id=>{Object.assign(inputs[id],{
 value:'SYNTHETIC_CANARY',defaultValue:'SYNTHETIC_DEFAULT',valueAttribute:'SYNTHETIC_ATTRIBUTE'});});
assert(cleared(),'initial page display must clear browser-restored values');
fill();handlers['apexbeforepagesubmit.kcvCredential']({},'CREATE_OCI_CREDENTIAL');
assert(names.every(id=>inputs[id].value==='SYNTHETIC_CANARY'),'do not erase values before native POST serialization');
assert(names.every(id=>inputs[id].defaultValue==='SYNTHETIC_DEFAULT' && inputs[id].valueAttribute==='SYNTHETIC_ATTRIBUTE'),
 'the explicit create action must not run cleanup before native POST serialization');
for(const request of ['TEST_MODEL','CONFIGURE_PROFILE','ENSURE_NETWORK','REFRESH',undefined]){
 fill();handlers['apexbeforepagesubmit.kcvCredential']({},request);
 assert(cleared(),'unrelated request must not submit credential input');
}
for(const name of ['pagehide','pageshow']){fill();windowHandlers[name]();assert(cleared());}
names.forEach(id=>{inputs[id].value=inputs[id].defaultValue;});
assert(cleared(),'a later form reset must not restore the cleared default');
assert(names.every(id=>inputs[id].type==='password'),'cleanup must never unmask input');
delete inputs[names[0]];windowHandlers.pageshow();
process.stdout.write('cleanup behavior PASS');
"""
        harness = harness.replace("__NAMES__", json.dumps(list(FIELDS))).replace("__CODE__", json.dumps(code))
        result = subprocess.run(["node", "-e", harness], text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "cleanup behavior PASS")


if __name__ == "__main__":
    unittest.main()
