CMD=$1
if [ -z "$CMD" ]; then
	CMD=getCusts
fi
RESULT=$( wget -O - "http://localhost:8090/$CMD?token=Testing&acc=fred" 2> /dev/null )

echo Result="$RESULT"
