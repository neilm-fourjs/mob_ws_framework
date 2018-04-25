
-- Mobile Web Server Demo

IMPORT com
IMPORT util
IMPORT os
IMPORT FGL gl_lib_restful
IMPORT FGL lib_secure
IMPORT FGL mob_ws_db

DEFINE m_ret RECORD
		stat SMALLINT,
		type STRING,
  	reply STRING
	END RECORD
DEFINE m_user STRING

MAIN
  DEFINE l_ret INTEGER
  DEFINE l_req com.HTTPServiceRequest
	DEFINE l_str STRING
	DEFINE l_quit BOOLEAN
  DEFER INTERRUPT

	CALL mob_ws_db.db_connect()

  DISPLAY "Starting server..."
  #
  # Starts the server on the port number specified by the FGLAPPSERVER environment variable
  #  (EX: FGLAPPSERVER=8090)
  # 
	TRY
  	CALL com.WebServiceEngine.Start()
  	DISPLAY "The server is listening."
	CATCH
		DISPLAY STATUS,":",ERR_GET(STATUS)
		EXIT PROGRAM
	END TRY

  WHILE NOT l_quit
	  TRY
  		# create the server
		  LET l_req = com.WebServiceEngine.getHTTPServiceRequest(-1)
		  CALL gl_lib_restful.gl_getReqInfo(l_req)

		  DISPLAY "Processing request, Method:", gl_lib_restful.m_reqInfo.method, " Path:", gl_lib_restful.m_reqInfo.path, " format:", gl_lib_restful.m_reqInfo.outformat
		  -- parse the url, retrieve the operation and the operand
		  CASE gl_lib_restful.m_reqInfo.method
			  WHEN "GET"
					CASE
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getToken") 
							CALL getToken()
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("getCusts") 
							CALL getCusts()
						OTHERWISE
							CALL setReply(201,%"ERR",SFMT(%"Operation '%1' not found",gl_lib_restful.m_reqInfo.path))
					END CASE
					DISPLAY "Get Reply:", m_ret.reply
					LET l_str = util.JSON.stringify(m_ret)
			  WHEN "POST"
					CASE
						WHEN gl_lib_restful.m_reqInfo.path.equalsIgnoreCase("putPhoto") 
							CALL putPhoto(l_req)
						OTHERWISE
							CALL setReply(201,%"ERR",SFMT(%"Operation '%1' not found",gl_lib_restful.m_reqInfo.path))
					END CASE
					DISPLAY "Post Reply:", m_ret.reply
					LET l_str = util.JSON.stringify(m_ret)
			  OTHERWISE
					CALL gl_lib_restful.gl_setError("Unknown request:\n"||m_reqInfo.path||"\n"||m_reqInfo.method)
					LET gl_lib_restful.m_err.code = -3
					LET gl_lib_restful.m_err.desc = SFMT(%"Method '%' not supported",gl_lib_restful.m_reqInfo.method)
					LET l_str = util.JSON.stringify(m_err)
		  END CASE
			-- send back the response.
			CALL l_req.setResponseHeader("Content-Type","application/json")
			DISPLAY "Replying:",l_str
			CALL l_req.sendTextResponse(200, "Ok!", l_str)
		  IF int_flag != 0 THEN LET int_flag=0 EXIT WHILE END IF
		CATCH
			LET l_ret = STATUS
			CASE l_ret
				WHEN -15565
					DISPLAY "Disconnected from application server."
					EXIT WHILE
				OTHERWISE
					DISPLAY "[ERROR] "||l_ret
					EXIT WHILE
				END CASE
		END TRY
	END WHILE
	DISPLAY "Service Exited."
END MAIN
--------------------------------------------------------------------------------
FUNCTION setReply(l_stat SMALLINT, l_typ STRING, l_msg STRING)
	LET m_ret.stat = l_stat
	LET m_ret.type = l_typ
	LET m_ret.reply = l_msg
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getToken()
	DEFINE x SMALLINT
	DEFINE l_xml, l_user, l_pass STRING

	LET x = gl_lib_restful.gl_getParameterIndex("xml") 
	IF x = 0 THEN
		CALL setReply(201,%"ERR",%"Missing parameter 'xml'!")
		RETURN
	END IF
	LET l_xml = gl_lib_restful.gl_getParameterValue(x)
	IF l_xml.getLength() < 10 THEN
		CALL setReply(203,%"ERR",SFMT(%"XML looks invalid '%1'!",l_xml))
		RETURN
	END IF

	CALL lib_secure.glsec_decryptCreds( l_xml ) RETURNING l_user, l_pass

	LET m_ret.reply = db_check_user( l_user, l_pass )
	IF m_ret.reply IS NULL THEN
		CALL setReply(202,%"ERR",%"Login Invalid!")
		RETURN
	END IF

	LET m_ret.stat = 200
	LET m_ret.type = "OK"
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION check_token() RETURNS BOOLEAN
	DEFINE x SMALLINT
	DEFINE l_token, l_res STRING

	LET x = gl_lib_restful.gl_getParameterIndex("token") 
	IF x = 0 THEN
		CALL setReply(201,%"ERR",%"Missing parameter 'token'!")
		RETURN FALSE
	END IF
	LET l_token = gl_lib_restful.gl_getParameterValue(x)
	LET l_res = mob_ws_db.db_check_token( l_token )
	IF l_res.subString(1,5) = "ERROR" THEN
		CALL setReply(201,%"ERR",l_res)
		RETURN FALSE
	END IF
	LET m_user = l_res
	RETURN TRUE
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getCusts()
	DEFINE l_data STRING

	IF NOT check_token() THEN RETURN END IF

	DISPLAY "Return customer list for user:",m_user

	LET l_data = db_get_custs()

	LET m_ret.stat = 200
	LET m_ret.type = "OK"
	LET m_ret.reply = l_data
END FUNCTION
--------------------------------------------------------------------------------
-- putPhoto - handle a photo being received.
FUNCTION putPhoto(l_req com.HTTPServiceRequest)
	DEFINE l_photo_file STRING

	DISPLAY "Getting photo ..."

	IF NOT check_token() THEN RETURN END IF

	TRY
		LET l_photo_file = l_req.readFileRequest()
	CATCH
		LET m_ret.stat = 200
		LET m_ret.type = "OK"
		LET m_ret.reply = "Photo Receive Failed!"
		RETURN
	END TRY

	DISPLAY "Got Photo:", l_photo_file

	IF os.Path.exists( l_photo_file ) THEN
		LET m_ret.stat = 200
		LET m_ret.type = "OK"
		LET m_ret.reply = "Photo transfered"
	ELSE
		LET m_ret.stat = 200
		LET m_ret.type = "OK"
		LET m_ret.reply = "Photo Doesn't Exist!"
	END IF
END FUNCTION