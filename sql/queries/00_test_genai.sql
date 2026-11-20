-- KCV_LAB: run after profile creation; this makes a billable model call.
-- A response verifies the selected credential/profile/model path, not extraction quality.
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt=>'Reply with a short greeting.',profile_name=>'KCV_GENAI',action=>'chat') AS response
FROM dual
/
