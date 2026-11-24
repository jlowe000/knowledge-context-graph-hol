 SELECT COUNT(*) INTO l_n FROM kcv_settings WHERE setting_key='SCHEMA_VERSION' AND setting_value='1';
 require(l_n=1,'Baseline schema setting differs');
