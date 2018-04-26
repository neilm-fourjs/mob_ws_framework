--SCHEMA mob_database

-- A Genero Mobile demo with web service framework.

IMPORT util
IMPORT os

IMPORT FGL mob_lib
IMPORT FGL gl_lib

DEFINE m_custs DYNAMIC ARRAY OF RECORD
		acc CHAR(10),
		cust_name CHAR(30),
		add1 CHAR(30),
		add2 CHAR(30)
	END RECORD
DEFINE m_src_custs DYNAMIC ARRAY OF RECORD
		line1 STRING,
		line2 STRING
	END RECORD
DEFINE m_custs_date DATETIME YEAR TO SECOND
MAIN

	CALL mob_lib.init_app()

	IF NOT mob_lib.login() THEN
		EXIT PROGRAM
	END IF

	OPEN FORM main FROM "demo_main"
	DISPLAY FORM main
	DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network

	MENU
		ON ACTION list_custs
			CALL list_custs()
		ON ACTION take_photo
			CALL photo(TRUE)
		ON ACTION choose_photo
			CALL photo(FALSE)
		ON ACTION send_data
			CALL send_data()
		ON ACTION about
			CALL ui.interface.frontCall("Android","showAbout",[],[])
		ON ACTION quit
			EXIT MENU
		ON TIMER 10
			DISPLAY IIF( mob_lib.check_network(), "Connected","No Connection") TO f_network
	END MENU

END MAIN
--------------------------------------------------------------------------------
FUNCTION list_custs()
	DEFINE x SMALLINT

	IF m_custs.getLength() = 0 THEN
		CALL get_custs()
	END IF

	OPEN WINDOW custs WITH FORM "cust_list" 

	FOR x = 1 TO m_custs.getLength()
		LET m_src_custs[x].line1 = m_custs[x].acc," ",m_custs[x].cust_name
		LET m_src_custs[x].line2 = m_custs[x].add1
	END FOR
	MESSAGE "Data as of: "||m_custs_date
	DISPLAY ARRAY m_src_custs TO scr_arr.* ATTRIBUTES(ACCEPT=FALSE,CANCEL=FALSE)
		ON ACTION select
			CALL show_cust( arr_curr() )
		ON ACTION back EXIT DISPLAY
	END DISPLAY

	CLOSE WINDOW custs
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION show_cust(l_cust SMALLINT)
	DEFINE l_extra RECORD
		extra_data CHAR(60)
	END RECORD
	DEFINE l_json STRING
	DEFINE l_updated_date, l_now DATETIME YEAR TO SECOND

	LET l_now = CURRENT
	OPEN WINDOW cust_det WITH FORM "cust_dets"

	SELECT extra, updated_date
		INTO l_extra.extra_data, l_updated_date
	 FROM custdets WHERE acc = m_custs[ l_cust ].acc

	IF l_updated_date IS NOT NULL
	AND l_updated_date > ( l_now - 1 UNITS DAY ) THEN
-- got data from db and current
	ELSE
		IF NOT mob_lib.check_network() THEN
			IF l_updated_date IS NULL THEN
				CALL gl_lib.gl_winMessage("Error","Not connected and not available locally","exclamation")
			ELSE
-- data is stale
			END IF
		ELSE
			LET l_updated_date = l_now
			LET l_json = mob_lib.ws_get_custDets( m_custs[ l_cust ].acc )
			CALL util.JSON.parse(l_json, l_extra)
			DELETE FROM custdets WHERE acc = m_custs[ l_cust ].acc
			INSERT INTO custdets VALUES(m_custs[ l_cust ].acc, l_extra.extra_data, l_now)
		END IF
	END IF

	DISPLAY "Data as of: "||l_updated_date TO f_info
	DISPLAY BY NAME m_custs[ l_cust ].*
	DISPLAY l_extra.extra_data TO f_extra

	MENU
		ON ACTION back EXIT MENU
		ON ACTION close EXIT MENU
	END MENU

	CLOSE WINDOW cust_det
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_custs()
	DEFINE x SMALLINT
	DEFINE l_json STRING
	DEFINE l_user_local BOOLEAN
	DEFINE l_updated_date DATETIME YEAR TO SECOND
	DEFINE l_now DATETIME YEAR TO SECOND

	LET l_user_local = FALSE
	LET l_now = CURRENT
	SELECT updated_date INTO l_updated_date FROM table_updated WHERE table_name = "customers"
	IF l_updated_date IS NOT NULL
	AND l_updated_date > ( l_now - 1 UNITS DAY ) THEN
		LET l_user_local = TRUE
	END IF

	IF NOT mob_lib.check_network() THEN  -- no connection
		IF NOT l_user_local AND l_updated_date IS NOT NULL THEN -- stale data
			CALL gl_lib.gl_winMessage("Warning",SFMT("Data is from %1\nYou are not connected to a network",l_updated_date),"exclamation")
			LET l_user_local = TRUE
		END IF
		IF l_updated_date IS NULL THEN -- no data
			CALL gl_lib.gl_winMessage("Error","No local data and no connection!","exclamation")
			LET m_custs_date = NULL
			RETURN
		END IF
	END IF

	IF l_user_local THEN
		DECLARE cust_cur CURSOR FOR SELECT * FROM customers
		FOREACH cust_cur INTO m_custs[ m_custs.getLength() + 1].*
		END FOREACH
		CALL m_custs.deleteElement( m_custs.getLength() )
		LET m_custs_date = l_updated_date
		RETURN
	END IF

	LET l_json = mob_lib.ws_get_custs()
	IF l_json IS NOT NULL THEN
		CALL util.JSON.parse(l_json, m_custs )
	ELSE
		ERROR "Failed to get Customers"
		RETURN
	END IF

	DELETE FROM customers
	FOR x = 1 TO m_custs.getLength()
		INSERT INTO customers VALUES( m_custs[x].* )
	END FOR
	LET m_custs_date = l_now
	DELETE FROM table_updated WHERE table_name = "customers"
	INSERT INTO table_updated VALUES("customers",l_now )
	MESSAGE m_custs.getLength()," from server"
	DISPLAY m_custs.getLength()," from server"
END FUNCTION
--------------------------------------------------------------------------------
-- Photo
FUNCTION photo(l_take BOOLEAN)
  DEFINE l_photo_file, l_local_file, l_ret STRING
	DEFINE l_image BYTE
	OPEN WINDOW show_photo WITH FORM "show_photo"

	IF l_take THEN
		CALL ui.Interface.frontCall("mobile","takePhoto",[],[l_photo_file])
	ELSE
		CALL ui.Interface.frontCall("mobile","choosePhoto",[],[l_photo_file])
	END IF
	DISPLAY l_photo_file TO f_lpath
	DISPLAY l_photo_file TO f_photo

	LET l_local_file = util.Datetime.format( CURRENT, "%Y%m%d_%H%M%S.jpg" )
	TRY
		CALL fgl_getfile(l_photo_file,l_local_file)
	CATCH
		CALL gl_lib.gl_winMessage("Error",ERR_GET( STATUS ),"exclamation")
	END TRY
	DISPLAY l_local_file TO f_path
	IF os.path.exists( l_local_file ) THEN
		DISPLAY "Exists:"||l_local_file TO f_path
	ELSE
		DISPLAY "Missing:"||l_local_file TO f_path
	END IF
	DISPLAY os.path.size(l_local_file) TO f_size
	LOCATE l_image IN FILE l_local_file
	DISPLAY l_image TO f_photo

	MENU
		ON ACTION send
			IF mob_lib.check_network() THEN
				LET l_ret = mob_lib.ws_post_file( l_local_file, os.path.size(l_local_file) )
				CALL gl_lib.gl_winMessage("Info",l_ret,"information")
			ELSE
				CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
			END IF
		ON ACTION back EXIT MENU
	END MENU
	CLOSE WINDOW show_photo
END FUNCTION
--------------------------------------------------------------------------------
-- send some data to the server
FUNCTION send_data()
	DEFINE l_data STRING

	LET l_data = util.JSON.stringify(m_custs)
	IF mob_lib.check_network() THEN
		CALL mob_lib.ws_send_data(l_data)
	ELSE
		CALL gl_lib.gl_winMessage("Error","No network connection","exclamation")
	END IF
END FUNCTION