
-- DB Functions

IMPORT FGL lib_secure
IMPORT security
IMPORT util

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
	DEFINE l_token_date, l_now DATETIME YEAR TO SECOND
	LET l_now = CURRENT
	SELECT pass_hash, salt, token, token_date  
		INTO l_pass_hash, l_salt, l_token, l_token_date
		FROM ws_users WHERE username = l_user
	IF STATUS = NOTFOUND THEN
		LET l_token = db_register_user(l_user,l_pass)
		DISPLAY "Registered user '", l_user CLIPPED,"' with token '",l_token,"'"
		RETURN l_token.trim()
	END IF
	IF NOT lib_secure.glsec_chkPassword(l_pass ,l_pass_hash ,l_salt, NULL ) THEN
		DISPLAY "User '", l_user CLIPPED,"' password mismatch!"
		RETURN NULL
	END IF
	IF l_token_date > ( l_now - 1 UNITS DAY ) THEN
		DISPLAY "User '", l_user CLIPPED,"' Registered Already with token '",l_token,"'"
		RETURN l_user
	ELSE
		LET l_token = security.RandomGenerator.CreateUUIDString()
		UPDATE ws_users SET ( token, token_date ) = ( l_token, l_now )
			WHERE username = l_user
		DISPLAY "User '", l_user CLIPPED,"' Registered Already but token expired, new is '",l_token,"'"
	END IF
	RETURN l_token.trim()
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
-- Get Customers
--
FUNCTION db_get_custs() RETURNS STRING
DEFINE l_custs DYNAMIC ARRAY OF RECORD
		acc CHAR(10),
		cust_name CHAR(30),
		add1 CHAR(30),
		add2 CHAR(30)
	END RECORD
	DEFINE x SMALLINT

	FOR x = 1 TO 5
		LET l_custs[x].acc = "TEST-"||x
		CASE x
			WHEN 1 LET l_custs[x].cust_name = "Neil"
						LET l_custs[x].add1 = "20a Somewhere rd"
			WHEN 2 LET l_custs[x].cust_name = "Paul"
						LET l_custs[x].add1 = "The Chapel"
			WHEN 3 LET l_custs[x].cust_name = "John"
						LET l_custs[x].add1 = "1 Abbey Rd"
			WHEN 4 LET l_custs[x].cust_name = "Mike"
						LET l_custs[x].add1 = "5 Smith Street"
			WHEN 5 LET l_custs[x].cust_name = "Fred"
						LET l_custs[x].add1 = "10 Bloggs rd"
		END CASE
	END FOR
	RETURN util.JSON.stringify(l_custs)
END FUNCTION
--------------------------------------------------------------------------------
-- Check the Token used is registered to a user and not expired.
--
-- @params l_user User
-- @params l_pass Password
-- @returns
FUNCTION db_check_token( l_token STRING ) RETURNS STRING
	DEFINE l_user STRING
	DEFINE l_token_date, l_now DATETIME YEAR TO SECOND

	IF l_token = "Testing" THEN RETURN "test" END IF

	SELECT username, token_date INTO l_user, l_token_date FROM ws_users WHERE token = l_token
	IF STATUS = NOTFOUND THEN
		RETURN SFMT("ERROR: Invalid Token '%1'!",l_token)
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