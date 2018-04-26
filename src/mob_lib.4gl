-- Core Mobile Library Code
IMPORT com
IMPORT util
IMPORT os
IMPORT FGL gl_lib
IMPORT FGL lib_secure

CONSTANT DB_VER = 1
CONSTANT WS_VER = 2

PRIVATE DEFINE m_security_token STRING
PUBLIC DEFINE m_connected BOOLEAN
PUBLIC DEFINE m_ret RECORD
		ver SMALLINT,
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
		IF l_ver = DB_VER THEN
			DISPLAY "DB Ver ",l_ver," Okay"
			RETURN TRUE
		END IF
	CATCH
		LET l_init_db = TRUE
		CREATE TABLE db_version (
			version SMALLINT
		)
		LET l_ver = DB_VER
	END TRY

	DISPLAY "Initializing DB ..."
	DELETE FROM db_version
	INSERT INTO db_version VALUES(DB_VER)
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

	TRY
		DROP TABLE customers
	CATCH
	END TRY
	CREATE TABLE customers (
		acc CHAR(10),
		cust_name CHAR(30),
		add1 CHAR(30),
		add2 CHAR(30)
	)

	TRY
		DROP TABLE table_updated
	CATCH
	END TRY
	CREATE TABLE table_updated (
		table_name CHAR(20),
		updated_date DATETIME YEAR TO SECOND
	)

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION login() RETURNS BOOLEAN
	DEFINE l_user, l_pass STRING
	DEFINE l_salt, l_pass_hash STRING
	DEFINE l_now, l_token_date DATETIME YEAR TO SECOND 

	OPEN FORM mob_login FROM "mob_login"
	DISPLAY FORM mob_login
	DISPLAY "Welcome to a simple GeneroMobile demo" TO welcome
	DISPLAY IIF( check_network(), "Connected","No Connection") TO f_network

	WHILE TRUE
		INPUT BY NAME l_user, l_pass

		IF int_flag THEN EXIT PROGRAM END IF
		LET l_now = CURRENT
		LET l_salt = NULL
		SELECT pass_hash, salt, token, token_date  
			INTO l_pass_hash,l_salt,m_security_token, l_token_date
			FROM users WHERE username = l_user
		IF STATUS != NOTFOUND THEN
			IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
				CALL gl_lib.gl_winMessage("Error","Login Failed","exclamation")
				CONTINUE WHILE
			END IF 
			IF l_token_date > ( l_now - 1 UNITS DAY ) THEN EXIT WHILE END IF -- all okay, exit the while
		END IF
-- user not in DB or token expired - connect to server for login check / new token.
		IF NOT set_security_token( l_user, l_pass ) THEN RETURN FALSE END IF
		IF l_salt IS NULL THEN
			LET l_salt = lib_secure.glsec_genSalt( NULL )
			LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
			INSERT INTO users VALUES(l_user, l_pass_hash, l_salt, m_security_token, l_now )
		ELSE
			UPDATE users SET ( token, token_date ) = ( m_security_token, l_now )
				WHERE username = l_user
		END IF

		EXIT WHILE

	END WHILE

	DISPLAY "Security Token is '", m_security_token,"'"

	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION check_network() RETURNS BOOLEAN
	DEFINE l_network STRING
	LET m_connected = FALSE

	IF ui.Interface.getFrontEndName() = "GDC" THEN
		LET m_connected = TRUE
		RETURN m_connected
	END IF

	CALL ui.Interface.frontCall("mobile", "connectivity", [], [l_network] )
	IF l_network = "WIFI" OR l_network = "MobileNetwork" THEN
		LET m_connected = TRUE
	END IF
	RETURN m_connected
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION set_security_token( l_user STRING, l_pass STRING )
	DEFINE l_xml_creds STRING
-- encrypt the username and password attempt
	LET l_xml_creds = lib_secure.glsec_encryptCreds(l_user, l_pass)
	IF l_xml_creds IS NULL THEN RETURN FALSE END IF

-- call the restful service to get the security token
	IF NOT doRestRequest( SFMT("getToken?xml=%1",l_xml_creds)) THEN
		RETURN FALSE
	END IF

	IF m_ret.ver != WS_VER THEN
		CALL gl_lib.gl_winMessage("Error",SFMT("Webversion Version Mismatch\nGot %1, expected %2",m_ret.ver,WS_VER),"exclamation")
	END IF

	LET m_security_token = m_ret.reply
	IF m_security_token IS NOT NULL THEN RETURN TRUE END IF
	RETURN FALSE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION ws_get_custs() RETURNS STRING
	IF NOT doRestRequest(SFMT("getCusts?token=%1",m_security_token)) THEN
		RETURN NULL
	END IF
	DISPLAY m_ret.reply
	RETURN m_ret.reply
END FUNCTION

--------------------------------------------------------------------------------
-- Do the web service REST call to check for a new GDC
PRIVATE FUNCTION doRestRequest(l_param STRING) RETURNS BOOLEAN
	DEFINE l_url STRING
  DEFINE l_req com.HttpRequest
  DEFINE l_resp com.HttpResponse
  DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mobdemo.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))
--	DISPLAY "URL:",l_url
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
      CALL gl_lib.gl_winMessage("WS Error",SFMT("WS call failed!\n%1\n%2-%3",l_url,l_stat, l_resp.getStatusDescription()),"exclamation")
    END IF
  CATCH
    LET l_stat = STATUS
    LET m_ret.reply = ERR_GET( l_stat )
  END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION


--------------------------------------------------------------------------------
FUNCTION ws_post_file(l_photo_file STRING, l_size INTEGER) RETURNS STRING
	IF NOT doRestRequestPhoto(SFMT("putPhoto?token=%1",m_security_token),l_photo_file, l_size) THEN
	END IF
	DISPLAY m_ret.reply
	RETURN m_ret.reply
END FUNCTION
--------------------------------------------------------------------------------
-- Do the web service REST call to check for a new GDC
PRIVATE FUNCTION doRestRequestPhoto(l_param STRING, l_photo_file STRING, l_size INTEGER) RETURNS BOOLEAN
	DEFINE l_url STRING
  DEFINE l_req com.HttpRequest
  DEFINE l_resp com.HttpResponse
  DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mobdemo.ws_url")||l_param
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))
--	DISPLAY "URL:",l_url
-- Do Rest call to find out if we have a new GDC Update
	DISPLAY "File:",l_photo_file, " Size:",l_size
  TRY
    LET l_req = com.HttpRequest.Create(l_url)
    CALL l_req.setMethod("POST")
    CALL l_req.setHeader("Content-Type", "image/jpg")
    CALL l_req.setHeader("Accept", "application/json")
		CALL l_req.setVersion("1.0")
	--	CALL l_req.setHeader("Content-Length", l_size )
		CALL l_req.doFileRequest(l_photo_file)
    LET l_resp = l_req.getResponse()
    LET l_stat = l_resp.getStatusCode()
    IF l_stat = 200 THEN
      CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
    ELSE
      CALL gl_lib.gl_winMessage("WS Error",SFMT("WS call failed!\n%1\n%2-%3",l_url,l_stat, l_resp.getStatusDescription()),"exclamation")
    END IF
  CATCH
    LET l_stat = STATUS
    LET m_ret.reply = ERR_GET( l_stat )
  END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("Error", m_ret.reply,"exclamation")
		RETURN FALSE
	END IF
	RETURN TRUE
END FUNCTION


--------------------------------------------------------------------------------
-- Send some json data back to server
--
-- @params l_data String JSON data
FUNCTION ws_send_data(l_data STRING)
	DEFINE l_url STRING
  DEFINE l_req com.HttpRequest
  DEFINE l_resp com.HttpResponse
  DEFINE l_stat SMALLINT

	LET l_url = fgl_getResource("mobdemo.ws_url")||"sendData"
	CALL gl_lib.gl_logIt("doRestRequest URL:"||NVL(l_url,"NULL"))
	DISPLAY "URL:",l_url
-- Do Rest call to find out if we have a new GDC Update

  TRY
    LET l_req = com.HttpRequest.Create(l_url)
    CALL l_req.setMethod("POST")
    CALL l_req.setHeader("Content-Type", "application/json")
    CALL l_req.setHeader("Accept", "application/json")
	--	CALL l_req.setHeader("Content-Length", l_size )
		CALL l_req.doTextRequest(l_data)
    LET l_resp = l_req.getResponse()
    LET l_stat = l_resp.getStatusCode()
    IF l_stat = 200 THEN
      CALL util.JSON.parse( l_resp.getTextResponse(), m_ret )
    ELSE
      CALL gl_lib.gl_winMessage("WS Error",SFMT("WS call failed!\n%1\n%2-%3",l_url,l_stat, l_resp.getStatusDescription()),"exclamation")
    END IF
  CATCH
    LET l_stat = STATUS
    LET m_ret.reply = ERR_GET( l_stat )
  END TRY
	CALL gl_lib.gl_logIt("m_ret reply:"||NVL(m_ret.reply,"NULL"))
	IF m_ret.stat != 200 THEN
		CALL gl_lib.gl_winMessage("Error", m_ret.reply,"exclamation")
		RETURN
	END IF
	RETURN 
  
END FUNCTION