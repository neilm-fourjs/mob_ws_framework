--SCHEMA mob_database
IMPORT FGL mob_lib
IMPORT FGL gl_lib
MAIN

	CALL mob_lib.init_app()

	IF NOT mob_lib.login() THEN
		EXIT PROGRAM
	END IF

	CALL gl_lib.gl_winMessage("Hello","Welcome","information")

END MAIN
