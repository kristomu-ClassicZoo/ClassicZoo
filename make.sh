#!/bin/bash

PROPERTIES_FILE=build.properties
EXECUTABLE_NAME=SUPERZ.EXE
OUTPUT_ARCHIVE=superzoo.zip
TPC_DEFINES=""
TEMP_PATH=$(mktemp -d /tmp/zoo.XXXXXXXXXXXX)
CLEANUP=yes
FREE_PASCAL=

# Parse arguments

OPTIND=1
while getopts "d:e:fo:p:r" opt; do
	case "$opt" in
	d)
		if [ -n "$TPC_DEFINES" ]; then
			TPC_DEFINES=$TPC_DEFINES","$OPTARG
		else
			TPC_DEFINES=$OPTARG
		fi
		;;
	e)
		EXECUTABLE_NAME=$OPTARG
		;;
	f)
		FREE_PASCAL=yes
		;;
	o)
		OUTPUT_ARCHIVE=$OPTARG
		;;
	p)
		PROPERTIES_FILE=$OPTARG
		;;
	r)
		CLEANUP=
		;;
	esac
done
shift $((OPTIND - 1))

TPC_ARGS=""
FPC_ARGS=""
if [ -n "$TPC_DEFINES" ]; then
	TPC_ARGS="$TPC_ARGS"' /D'"$TPC_DEFINES"
	FPC_ARGS="$FPC_ARGS"' -d'"$TPC_DEFINES"
fi

if [ ! -d "OUTPUT" ]; then
	mkdir "OUTPUT"
fi

echo "Preparing Pascal code..."

for i in DOC RES SCREENS SRC SYSTEM TOOLS VENDOR LICENSE.TXT; do
	cp -R "$i" "$TEMP_PATH"/
done
cp -R "$TEMP_PATH"/SYSTEM/*.BAT "$TEMP_PATH"/

for i in BUILD DIST; do
	mkdir "$TEMP_PATH"/"$i"
done

# Replace symbols with ones from PROPERTIES_FILE
if [ -f "$PROPERTIES_FILE" ]; then
	while IFS='=' read -r KEY VALUE; do
		for i in "$TEMP_PATH"/SRC/*.*; do
			sed -i -e 's#%'"$KEY"'%#'"$VALUE"'#g' "$i"
		done
	done < "$PROPERTIES_FILE"
fi

sed -i -e 's#%COMPARGS%#'"$TPC_ARGS"'#g' "$TEMP_PATH"/BUILD.BAT
sed -i -e 's#%FPC_PATH%#'"$FPC_PATH"'#g' "$TEMP_PATH"/SYSTEM/fpc.cfg
echo "Compiling Pascal code..."

RETURN_PATH=$(pwd)
cd "$TEMP_PATH"

if [ -n "$FREE_PASCAL" ]; then
	if [ ! -d "$FPC_PATH" ]; then
		echo "Please set the FPC_PATH environment variable!"
		exit 1
	fi

	echo "[ Building tools ]"
	cd TOOLS
	cp ../SYSTEM/fpc.cfg .
	"$FPC_PATH"/bin/ppcross8086 BIN2PAS.PAS
	cp BIN2PAS.exe ../BUILD/BIN2PAS.EXE
	"$FPC_PATH"/bin/ppcross8086 CSIPACK.PAS
	cp CSIPACK.exe ../BUILD/CSIPACK.EXE
	cd ..

	sed -i -e "s/^BUILD$/RUNTOOLS/" SYSTEM/dosbox.conf
	touch BUILD.LOG
	SDL_VIDEODRIVER=dummy dosbox -noconsole -conf SYSTEM/dosbox.conf > /dev/null &
	tail --pid $! -n +1 -f BUILD.LOG

	echo "[ Building SUPERZ.EXE ]"
	cd SRC
	cp ../SYSTEM/fpc.cfg .
	"$FPC_PATH"/bin/ppcross8086 $FPC_ARGS SUPERZ.PAS
	cp SUPERZ.exe ../BUILD/SUPERZ.EXE
	cd ..
else
	touch BUILD.LOG
	SDL_VIDEODRIVER=dummy dosbox -noconsole -conf SYSTEM/dosbox.conf > /dev/null &
	tail --pid $! -n +1 -f BUILD.LOG
fi

if [ ! -f BUILD/SUPERZ.EXE ]; then
	cd "$RETURN_PATH"
	rm -r "$TEMP_PATH"
	exit 1
fi

# Post-processing

echo "Packaging..."

if [ ! -x "$(command -v upx)" ]; then
	echo "Not compressing - UPX is not installed!"
	cp BUILD/SUPERZ.EXE DIST/"$EXECUTABLE_NAME"
else
	echo "Compressing..."
	upx --8086 -9 -o DIST/"$EXECUTABLE_NAME" BUILD/SUPERZ.EXE
fi

cp LICENSE.TXT DIST/
if [ -d RES ]; then
	cp RES/* DIST/
fi

cd DIST
zip -9 -r "$RETURN_PATH"/OUTPUT/"$OUTPUT_ARCHIVE" .
cd ..

cd "$RETURN_PATH"
if [ -n "$CLEANUP" ]; then
	rm -r "$TEMP_PATH"
else
	echo 'Not cleaning up as requested; work directory: '"$TEMP_PATH"
fi
