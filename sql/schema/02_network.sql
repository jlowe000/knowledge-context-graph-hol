-- Run as KCV_LAB after Java/RDF readiness. One-time initial network setup.
BEGIN
  SEM_APIS.CREATE_RDF_NETWORK('DATA',network_owner=>USER,network_name=>'KCV_NET');
END;
/
