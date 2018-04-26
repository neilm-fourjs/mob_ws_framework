-- Core Mobile Library Code

IMPORT util
IMPORT os

IMPORT FGL mob_ws_lib
IMPORT FGL gl_lib
IMPORT FGL lib_secure

CONSTANT DB_VER = 2

DEFINE m_init_db BOOLEAN
PUBLIC DEFINE m_connected BOOLEAN

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
	DEFINE l_ver SMALLINT

	LET m_init_db = FALSE
	TRY
		SELECT version INTO l_ver FROM db_version
		IF l_ver = DB_VER THEN
			DISPLAY "DB Ver ",l_ver," Okay"
			RETURN TRUE
		END IF
	CATCH
		LET m_init_db = TRUE
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
		DROP TABLE custdets
	CATCH
	END TRY
	CREATE TABLE custdets (
		acc CHAR(10),
		extra CHAR(60),
		updated_date DATETIME YEAR TO SECOND
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
	DEFINE l_token, l_salt, l_pass_hash, l_xml_creds STRING
	DEFINE l_now, l_token_date DATETIME YEAR TO SECOND 

	OPEN FORM mob_login FROM "mob_login"
	DISPLAY FORM mob_login
	DISPLAY "Welcome to a simple GeneroMobile demo" TO welcome
	DISPLAY IIF( check_network(), "Connected","No Connection") TO f_network

	IF m_init_db AND NOT check_network() THEN
		CALL gl_lib.gl_winMessage("Error","First time Login requires a network connection\nConnect to network and try again","exclamation")
		EXIT PROGRAM
	END IF

	WHILE TRUE
		INPUT BY NAME l_user, l_pass
		IF int_flag THEN EXIT PROGRAM END IF

		LET l_now = CURRENT
		LET l_salt = NULL
		SELECT pass_hash, salt, token, token_date  
			INTO l_pass_hash,l_salt, l_token, l_token_date
			FROM users WHERE username = l_user
		IF STATUS != NOTFOUND THEN
			IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
				CALL gl_lib.gl_winMessage("Error","Login Failed","exclamation")
				CONTINUE WHILE
			END IF 
			IF l_token_date > ( l_now - 1 UNITS DAY ) THEN EXIT WHILE END IF -- all okay, exit the while
		END IF
-- user not in DB or token expired - connect to server for login check / new token.
-- encrypt the username and password attempt
		LET l_xml_creds = lib_secure.glsec_encryptCreds(l_user, l_pass)
		IF l_xml_creds IS NULL THEN RETURN FALSE END IF
		LET l_token =  ws_getSecurityToken( l_xml_creds ) 
		IF l_token IS NULL THEN RETURN FALSE END IF
		IF l_salt IS NULL THEN
			LET l_salt = lib_secure.glsec_genSalt( NULL )
			LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
			INSERT INTO users VALUES(l_user, l_pass_hash, l_salt, l_token, l_now )
		ELSE
			UPDATE users SET ( token, token_date ) = ( l_token, l_now )
				WHERE username = l_user
		END IF
		EXIT WHILE
	END WHILE
	LET mob_ws_lib.m_security_token = l_token
	CALL gl_lib.gl_logIt("Security Token is '"||NVL(l_token.trim(),"NULL")||"'")

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
