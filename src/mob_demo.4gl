--SCHEMA mob_database
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

	MENU
		ON ACTION list_custs
			CALL list_custs()
		ON ACTION about
			CALL ui.interface.frontCall("Android","showAbout",[],[])
		ON ACTION quit
			EXIT MENU
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
	DISPLAY ARRAY m_src_custs TO scr_arr.*
		ON ACTION select
			CALL show_cust( arr_curr() )
	END DISPLAY

	CLOSE WINDOW custs
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION show_cust(l_cust SMALLINT)
	OPEN WINDOW cust_det WITH FORM "cust_dets"

	DISPLAY BY NAME m_custs[ l_cust ].*

	MENU
		ON ACTION close EXIT MENU
	END MENU

	CLOSE WINDOW cust_det
END FUNCTION
--------------------------------------------------------------------------------
FUNCTION get_custs()
	DEFINE l_param STRING
	LET l_param = "getCusts"
	CALL mob_lib.doRestRequest(l_param)
	DISPLAY mob_lib.m_ret.reply
	CALL util.JSON.parse(mob_lib.m_ret.reply, m_custs )
END FUNCTION
