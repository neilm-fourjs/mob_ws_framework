-- Core Mobile Library Code
IMPORT com
IMPORT util
IMPORT FGL gl_lib
IMPORT FGL lib_secure

PRIVATE DEFINE m_security_token STRING
DEFINE m_ret RECORD
		stat SMALLINT,
		type STRING,
  	reply STRING
	END RECORD

FUNCTION init_app()
	DEFINE l_dbname STRING
	LET l_dbname = "mob_database.db"
	TRY
		CONNECT TO l_dbname
	CATCH
		CALL gl_lib.gl_winMessage("Error",SFMT(%"Failed to connect to '%1'!\n%2",l_dbname, SQLERRMESSAGE),"exclamation")
	END TRY
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION login()
	DEFINE l_user, l_pass STRING

	OPEN FORM mob_login FROM "mob_login"
	DISPLAY FORM mob_login
	
	INPUT BY NAME l_user, l_pass

	IF int_flag THEN RETURN FALSE END IF

	IF NOT set_security_token( l_user, l_pass ) THEN RETURN FALSE END IF

	DISPLAY "Security Token is:", m_security_token

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION set_security_token( l_user STRING, l_pass STRING )
	DEFINE l_xml_creds STRING
-- encrypt the username and password attempt
	LET l_xml_creds = lib_secure.glsec_encryptCreds(l_user, l_pass)
	IF l_xml_creds IS NULL THEN RETURN FALSE END IF

-- call the restful service to get the security token
	CALL doRestRequest( SFMT("getToken?xml=%1",l_xml_creds))

	LET m_security_token = m_ret.reply
	IF m_security_token IS NOT NULL THEN RETURN TRUE END IF
	RETURN FALSE
END FUNCTION
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Do the web service REST call to check for a new GDC
PRIVATE FUNCTION doRestRequest(l_param STRING)
	DEFINE l_url STRING
  DEFINE l_req com.HttpRequest
  DEFINE l_resp com.HttpResponse
  DEFINE l_stat SMALLINT

	LET l_url = "http://localhost:8090/ws/r/"||l_param

	DISPLAY "URL:",l_url
-- Do Rest call to find out if we have a new GDC Update
  TRY
    LET l_req = com.HttpRequest.Create(l_url)
    CALL l_req.setMethod("GET")
    CALL l_req.setHeader("Content-Type", "application/json")
    CALL l_req.setHeader("Accept", "application/json")
    CALL l_req.doRequest()
    LET l_resp = l_req.getResponse()
    LET l_stat = l_resp.getStatusCode()
    IF l_stat = 200 THEN
      CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
    ELSE
      CALL gl_lib.gl_winMessage("WS Error",SFMT("WS chkgdc call failed!\n%1\n%1-%2",l_url,l_stat, l_resp.getStatusDescription()),"exclamation")
    END IF
  CATCH
    LET l_stat = STATUS
    LET m_ret.reply = ERR_GET( l_stat )
  END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
END FUNCTION
