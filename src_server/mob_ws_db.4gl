
-- DB Functions

IMPORT FGL lib_secure
IMPORT security

--------------------------------------------------------------------------------
FUNCTION db_connect()

  CONNECT TO "njm_demo310"

	TRY
		CREATE TABLE ws_users (
			username CHAR(30),
			pass_hash CHAR(60),
			salt CHAR(60),
			token CHAR(60),
			token_date DATETIME YEAR TO SECOND
		)
	CATCH
	END TRY
END FUNCTION

--------------------------------------------------------------------------------
-- Check the user is registered with that password or register new user
-- 
-- @params l_user User
-- @params l_pass Password
-- @returns
FUNCTION db_check_user( l_user CHAR(30), l_pass CHAR(30) ) RETURNS STRING
	DEFINE l_token STRING
	DEFINE l_salt, l_pass_hash STRING
	SELECT pass_hash, salt, token  INTO l_pass_hash, l_salt, l_token FROM ws_users WHERE username = l_user
	IF STATUS = NOTFOUND THEN
		LET l_token = db_register_user(l_user,l_pass)
		DISPLAY "Registered user '", l_user CLIPPED,"' with token '",l_token,"'"
		RETURN l_token
	END IF
	IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
		DISPLAY "User '", l_user CLIPPED,"' password mismatch!"
		RETURN NULL
	END IF
	DISPLAY "User '", l_user CLIPPED,"' Registered Already with token '",l_token,"'"
	RETURN l_token
END FUNCTION
--------------------------------------------------------------------------------
-- Register new user
--
-- @params l_user User
-- @params l_pass Password
FUNCTION db_register_user( l_user CHAR(30), l_pass CHAR(30)) RETURNS STRING
	DEFINE l_token STRING
	DEFINE l_now DATETIME YEAR TO SECOND
	DEFINE l_salt, l_pass_hash STRING
	LET l_now = CURRENT
	LET l_token = security.RandomGenerator.CreateUUIDString()
	LET l_salt = lib_secure.glsec_genSalt( NULL )
	LET l_pass_hash = lib_secure.glsec_genPasswordHash(l_pass, l_salt, NULL)
  INSERT INTO ws_users VALUES( l_user, l_pass_hash, l_salt, l_token, l_now )
	RETURN l_token
END FUNCTION
--------------------------------------------------------------------------------
-- Check the Token used is registered to a user and not expired.
--
-- @params l_user User
-- @params l_pass Password
-- @returns
FUNCTION db_check_token( l_token CHAR(60) ) RETURNS STRING
	DEFINE l_user STRING
	DEFINE l_token_date, l_now DATETIME YEAR TO SECOND

	SELECT username, token_date INTO l_user, l_token_date FROM ws_users WHERE token = l_token
	IF STATUS = NOTFOUND THEN
		RETURN "ERROR: Invalid Token!"
	END IF

	LET l_now = CURRENT
	IF l_token_date > ( l_now - 1 UNITS DAY ) THEN
		DISPLAY "Token Okay"
		RETURN l_user
	ELSE
		RETURN "ERROR: Token expired!"
	END IF
END FUNCTION
--------------------------------------------------------------------------------