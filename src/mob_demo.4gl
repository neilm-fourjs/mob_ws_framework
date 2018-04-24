--SCHEMA mob_database

-- A Genero Mobile demo with web service framework.

IMPORT util

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
	DISPLAY ARRAY m_src_custs TO scr_arr.* ATTRIBUTES(ACCEPT=FALSE,CANCEL=FALSE)
		ON ACTION select
			CALL show_cust( arr_curr() )
		ON ACTION back EXIT DISPLAY
	END DISPLAY

	CLOSE WINDOW custs
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION show_cust(l_cust SMALLINT)
	OPEN WINDOW cust_det WITH FORM "cust_dets"

	DISPLAY BY NAME m_custs[ l_cust ].*

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
	DEFINE l_updated_date DATETIME YEAR TO SECOND
	DEFINE l_now DATETIME YEAR TO SECOND

	LET l_now = CURRENT
	SELECT updated_date INTO l_updated_date FROM table_updated WHERE table_name = "customers"
	IF l_updated_date IS NOT NULL
	AND l_updated_date > ( l_now - 1 UNITS DAY ) THEN
		DECLARE cust_cur CURSOR FOR SELECT * FROM customers
		FOREACH cust_cur INTO m_custs[ m_custs.getLength() + 1].*
		END FOREACH
		CALL m_custs.deleteElement( m_custs.getLength() )
		MESSAGE m_custs.getLength()," from local db"
		DISPLAY m_custs.getLength()," from local db"
		RETURN
	END IF

	LET l_json = ws_get_custs()
	IF l_json IS NOT NULL THEN
		CALL util.JSON.parse(l_json, m_custs )
	ELSE
		ERROR "Failed to get Customers"
		RETURN
	END IF

	FOR x = 1 TO m_custs.getLength()
		INSERT INTO customers VALUES( m_custs[x].* )
	END FOR

	DELETE FROM table_updated WHERE table_name = "customers"
	INSERT INTO table_updated VALUES("customers",l_now )
	MESSAGE m_custs.getLength()," from server"
	DISPLAY m_custs.getLength()," from server"
END FUNCTION
