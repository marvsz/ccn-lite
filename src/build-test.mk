# build-test.mk
# Set NO_CORES to the number of logical cores available, if not already set
OS:=$(shell sh -c 'uname -s 2> /dev/null || echo not')
ifeq ($(OS),Linux)
    NO_CORES?=$(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin) # Assume OS X
    NO_CORES?=$(shell sysctl -n hw.ncpu)
else
    NO_CORES?=1
endif
export NO_CORES

# Check VERBOSE variable
ifdef VERBOSE
    PRINT_LOG=( echo "Contents of /tmp/$@.log:"; cat "/tmp/$@.log"; echo; exit 1 )
else
    PRINT_LOG=( exit 1 )
endif

# Get effective user id (0 for root)
EUID:=$(shell sh -c 'id -u')

# Check if arduino is available
ARDUINO_RC:=$(shell which arduino > /dev/null; echo $$?)
ANDROID_RC:=$(shell { which android && which ndk-build && which ant; } > /dev/null; echo $$?)
OMNET_RC:=$(shell { which omnetpp && test -d $(INET_HOME); } > /dev/null; echo $$?)

BT_RELAY:=bt-relay-nothing \
	bt-relay-barebones \
	bt-relay-vanilla \
	bt-relay-frag \
	bt-relay-authCtrl \
	bt-relay-nfn \
	bt-relay-nack \
	bt-relay-nfn-nack \
	bt-relay-all
BT_LNXKERNEL:=bt-lnxkernel
BT_OMNET:=bt-omnet
BT_ALL:=bt-all-vanilla \
	bt-all-nfn

SHIELDS:=ethernet wifly
BOARDS:=uno
BT_ARDUINO:=$(foreach S,$(SHIELDS),$(foreach B,$(BOARDS),bt-arduino-$(S)-$(B)))
BT_RFDUINO:=bt-rfduino

BT_ANDROID:=bt-android

PKT_FORMATS:=ccnb ccntlv cistlv iottlv ndntlv
BT_PKT:=$(addprefix bt-pkt-,${PKT_FORMATS})

SUITES:=ccnb ccnx2015 cisco2015 iot2014 ndn2013
BT_DEMO:=$(addprefix bt-demo-,${SUITES})
BT_DEMO_KRNL:=$(addprefix bt-demo-krnl-,${SUITES})
BT_NFN:=$(addprefix bt-nfn-,${SUITES})

PROFILES:=${BT_RELAY} ${BT_LNXKERNEL} ${BT_ALL}
PROFILES_STR:=relay, lnxkernel, all,
ifeq ($(OMNET_RC),0)
    PROFILES+=${BT_OMNET}
    PROFILES_STR+=omnet,
endif
ifeq ($(ARDUINO_RC),0)
    PROFILES+=${BT_ARDUINO} ${BT_RFDUINO}
    PROFILES_STR+=arduino, rfduino,
endif
ifeq ($(ANDROID_RC),0)
    PROFILES+=${BT_ANDROID}
    PROFILES_STR+=android,
endif
PROFILES+=${BT_PKT} ${BT_DEMO}
PROFILES_STR+=pkt, demo,
# Include BT_DEMO_KRNL only on Linux under root
ifeq ($(OS),Linux)
    ifeq ($(EUID),0)
        PROFILES+=${BT_DEMO_KRNL}
        PROFILES_STR+=demo-krnl,
	endif
endif
PROFILES+=${BT_NFN}
PROFILES_STR+=nfn

.PHONY: echo-cores all clean clean-logs bt-relay bt-all bt-pkt bt-demo ${PROFILES} ${BT_DEMO_KRNL} ${BT_OMNET} ${BT_RFDUINO} ${BT_ARDUINO} ${BT_ANDROID}
all: echo-cores ${PROFILES} clean
bt-relay: ${BT_RELAY} clean
bt-all: ${BT_ALL} clean
bt-pkt: ${BT_PKT} clean
bt-demo: ${BT_DEMO} clean
bt-demo-krnl: ${BT_DEMO_KRNL} clean
bt-nfn: ${BT_NFN} clean
bt-arduino: ${BT_ARDUINO} clean

echo-cores:
	@bash -c 'printf "\e[3mBuilding \e[1m$(PROFILES_STR)\e[0m\e[3m using \e[1m$(NO_CORES) cores:\e[0m\n"'

clean:
	@make clean USE_NFN=1 USE_NACK=1 > /dev/null 2>&1
	@if [ 0 -eq "${ANDROID_RC}" ]; then cd android && ndk-build clean > /dev/null && ant clean > /dev/null && cd ..; fi
	@if [ 0 -eq "${ARDUINO_RC}" ]; then cd arduino && make clean > /dev/null && cd ..; cd rfduino && make clean > /dev/null && cd ..; fi
	@echo ''
	@echo 'See /tmp/bt-*.log for more details.'

clean-logs:
	rm -rf /tmp/bt-*.log

bt-relay-nothing:
# Build without any USE_*
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	MODIFIY_FNAME=ccn-lite-relay.c \
	UNSET_VARS="USE_CCNxDIGEST USE_DEBUG USE_DEBUG_MALLOC USE_ECHO \
		USE_ETHERNET USE_HMAC256 USE_HTTP_STATUS USE_IPV4 USE_MGMT \
		USE_NACK USE_NFN USE_NFN_NSTRANS USE_NFN_MONITOR USE_SCHEDULER \
		USE_STATS USE_SUITE_CCNB USE_SUITE_CCNTLV USE_SUITE_CISTLV \
		USE_SUITE_IOTTLV USE_SUITE_NDNTLV USE_SUITE_LOCALRPC USE_UNIXSOCKET" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-barebones:
# Build only with USE_IPV4 and USE_SUITE_NDNTLV
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	MODIFIY_FNAME=ccn-lite-relay.c \
	SET_VARS="USE_IPV4 USE_SUITE_NDNTLV" \
	UNSET_VARS="USE_CCNxDIGEST USE_DEBUG USE_DEBUG_MALLOC USE_ECHO \
		USE_ETHERNET USE_HMAC256 USE_HTTP_STATUS USE_MGMT \
		USE_NACK USE_NFN USE_NFN_NSTRANS USE_NFN_MONITOR USE_SCHEDULER \
		USE_STATS USE_SUITE_CCNB USE_SUITE_CCNTLV USE_SUITE_CISTLV \
		USE_SUITE_IOTTLV USE_SUITE_LOCALRPC USE_UNIXSOCKET" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-vanilla:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-frag:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	MAKE_VARS="USE_FRAG=1" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-authCtrl:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	MAKE_VARS="USE_SIGNATURES=1" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-nfn:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-nfn-relay" \
	MAKE_VARS="USE_NFN=1" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-nack:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay-nack" \
	MAKE_VARS="USE_NFN=1 USE_NACK=1" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-nfn-nack:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-nfn-relay-nack" \
	MAKE_VARS="USE_NFN=1 USE_NACK=1" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-relay-all:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-relay" \
	MAKE_VARS="USE_FRAG=1 USE_SIGNATURES=1" \
	./build-test-helper.sh || ${PRINT_LOG}


bt-lnxkernel:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="ccn-lite-lnxkernel" \
	MAKE_VARS="USE_KRNL=1" \
	./build-test-helper.sh || ${PRINT_LOG}


bt-omnet:
	@MODE="omnet" \
	TARGET=$@ \
	./build-test-helper.sh || ${PRINT_LOG}


bt-all-vanilla:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="all" \
	./build-test-helper.sh || ${PRINT_LOG}

bt-all-nfn:
	@MODE="make" \
	TARGET=$@ \
	MAKE_TARGETS="all" \
	MAKE_VARS="USE_NFN=1" \
	./build-test-helper.sh || ${PRINT_LOG}


${BT_ARDUINO}:
	@SPLIT=$(@:bt-arduino-%=%); \
	MODE="arduino" \
	TARGET=$@ \
	SHIELD=$${SPLIT%-*} \
	BOARD=$${SPLIT#*-} \
	./build-test-helper.sh || ${PRINT_LOG}

bt-rfduino:
	@MODE="rfduino" \
	TARGET=$@ \
	./build-test-helper.sh || ${PRINT_LOG}


bt-android:
	@MODE="android" \
	TARGET=$@ \
	./build-test-helper.sh || ${PRINT_LOG}


${BT_PKT}: bt-all-vanilla
	@MODE="pkt-format" \
	TARGET=$@ \
	PKT_FORMAT=$(@:bt-pkt-%=%) \
	./build-test-helper.sh || ${PRINT_LOG}


${BT_DEMO}: bt-all-vanilla
	@MODE="demo-relay" \
	TARGET=$@ \
	SUITE=$(@:bt-demo-%=%) \
	WITH_KRNL="false" \
	./build-test-helper.sh || ${PRINT_LOG}


${BT_DEMO_KRNL}: bt-all-vanilla bt-lnxkernel
	@MODE="demo-relay" \
	TARGET=$@ \
	SUITE=$(@:bt-demo-krnl-%=%) \
	WITH_KRNL="true" \
	./build-test-helper.sh || ${PRINT_LOG}


${BT_NFN}: bt-all-nfn
	@MODE="nfn-test" \
	TARGET=$@ \
	SUITE=$(@:bt-nfn-%=%) \
	./build-test-helper.sh || ${PRINT_LOG}
