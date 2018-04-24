-- Core Mobile Library Code
IMPORT com
IMPORT util
IMPORT FGL gl_lib
IMPORT FGL lib_secure

CONSTANT DB_VER = 1

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
		RETURN
	END TRY

	IF NOT init_db() THEN
		CALL gl_lib.gl_winMessage("Error",SFMT(%"Failed to initialize '%1'!\n%2",l_dbname, SQLERRMESSAGE),"exclamation")
		RETURN
	END IF

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION init_db() RETURNS BOOLEAN
	DEFINE l_init_db BOOLEAN
	DEFINE l_ver SMALLINT
	TRY
		SELECT version INTO l_ver FROM db_version
	CATCH
		LET l_init_db = TRUE
		CREATE TABLE db_version (
			version SMALLINT
		)
		INSERT INTO db_version VALUES(DB_VER)
		LET l_ver = DB_VER
	END TRY
	IF l_ver = DB_VER THEN
		RETURN TRUE
	END IF

	TRY
		DROP TABLE users
	CATCH
	END TRY

	CREATE TABLE users (
		username CHAR(30),
		pass_hash CHAR(60),
		salt CHAR(60),
		token CHAR(60),
		token_date DATETIME YEAR TO SECOND
	)

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION login() RETURNS BOOLEAN
	DEFINE l_user, l_pass STRING
	DEFINE l_salt, l_passhash STRING
	DEFINE l_datetime DATETIME YEAR TO SECOND 

	OPEN FORM mob_login FROM "mob_login"
	DISPLAY FORM mob_login
	
	INPUT BY NAME l_user, l_pass

	IF int_flag THEN RETURN FALSE END IF

	SELECT pass_hash, salt, token  INTO l_passhash,l_salt,m_security_token FROM users WHERE username = l_user
	IF STATUS = NOTFOUND THEN
		IF NOT set_security_token( l_user, l_pass ) THEN RETURN FALSE END IF
		LET l_salt = lib_secure.glsec_genSalt( NULL )
		LET l_passhash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
		LET l_datetime = CURRENT
		INSERT INTO users VALUES(l_user, l_passhash, l_salt, m_security_token, l_datetime )
	ELSE
		IF NOT lib_secure.glsec_chkPassword(l_pass ,l_passhash ,l_salt, NULL ) THEN
			CALL gl_lib.gl_winMessage("Error","Login Failed","exclamation")
			RETURN FALSE
		END IF
	END IF

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

	LET l_url = fgl_getResource("mobdemo.ws_url")||l_param

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
      CALL gl_lib.gl_winMessage("WS Error",SFMT("WS call failed!\n%1\n%1-%2",l_url,l_stat, l_resp.getStatusDescription()),"exclamation")
    END IF
  CATCH
    LET l_stat = STATUS
    LET m_ret.reply = ERR_GET( l_stat )
  END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
END FUNCTION
