
-- GDCUPDATEURL is the url for the Genero App server to fetch the zip file
-- if the server is not the same machine.

IMPORT com
IMPORT util
IMPORT security
IMPORT FGL gl_lib_restful
IMPORT FGL lib_secure

DEFINE m_ret RECORD
		stat SMALLINT,
		type STRING,
  	reply STRING
	END RECORD

MAIN
  DEFINE l_ret INTEGER
  DEFINE l_req com.HTTPServiceRequest
	DEFINE l_str STRING
	DEFINE l_quit BOOLEAN
  DEFER INTERRUPT

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
					DISPLAY "Reply:", m_ret.reply
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
FUNCTION getToken()
	DEFINE x SMALLINT
	DEFINE l_xml, l_user, l_pass STRING
	LET x = gl_lib_restful.gl_getParameterIndex("xml") 
	IF x = 0 THEN
		CALL setReply(201,%"ERR",%"Missing parameter 'xml'!")
		RETURN
	END IF
	LET l_xml = gl_lib_restful.gl_getParameterValue(1)
	IF l_xml.getLength() < 10 THEN
		CALL setReply(203,%"ERR",SFMT(%"XML looks invalid '%1'!",l_xml))
		RETURN
	END IF

--	DISPLAY "Got:",l_xml

	CALL lib_secure.glsec_decryptCreds( l_xml ) RETURNING l_user, l_pass
--	DISPLAY "User:",l_user," Pass:",l_pass

	LET m_ret.stat = 200
	LET m_ret.type = "OK"
	LET m_ret.reply = security.RandomGenerator.CreateUUIDString()

END FUNCTION
--------------------------------------------------------------------------------
FUNCTION setReply(l_stat SMALLINT, l_typ STRING, l_msg STRING)
	LET m_ret.stat = l_stat
	LET m_ret.type = l_typ
	LET m_ret.reply = l_msg
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION getCusts()
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
	LET m_ret.stat = 200
	LET m_ret.type = "OK"
	LET m_ret.reply = util.JSON.stringify(l_custs)
END FUNCTION