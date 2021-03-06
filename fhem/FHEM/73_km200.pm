# $Id: 73_km200.pm 0035 2015-01-06 20:00:00Z Matthias_Deeke $
########################################################################################################################
#
#     73_km200.pm
#     Creates the possibility to access the Buderus central heating system via
#     Buderus KM200 or KM50 communication module. It uses HttpUtils_NonblockingGet
#     from Rudolf Koenig to avoid a full blockage of the fhem main system during 
#     polling procedure.
#
#     Author          : Matthias Deeke 
#     Contributions   :	Olaf Droegehorn, Andreas Hahn, Rudolf Koenig, Markus Bloch, Stefan M., Furban
#     e-mail          :	matthias.deeke(AT)deeke(PUNKT)eu
#     Fhem Forum      : http://forum.fhem.de/index.php/topic,25540.0.html
#     Fhem Wiki       : http://www.fhemwiki.de/wiki/Buderus_Web_Gateway
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
#     fhem.cfg: define <devicename> km200 <IPv4-address> <GatewayPassword> <PrivatePassword>
#
#     Example 1 - Bare Passwords:
#     define myKm200 km200 192.168.178.200 GatewayGeheim        PrivateGeheim
#
#     Example 2 - base64 encoded passwords: Both passwords may be pre-encode with base64
#     define myKm200 km200 192.168.178.200 R2F0ZXdheUdlaGVpbQ== UHJpdmF0ZUdlaGVpbQ==
#
########################################################################################################################
#                                               CHANGELOG
#
#     Version	Date		Programmer			Subroutine						Description of Change
#		1.00	28.08.2014	Sailor				All								Initial Release for collaborative programming work
#		1.01	13.10.2014	Furban				km200_Define					Correcting "if (int(@a) == 6))" into "if (int(@a) == 6)"
#		1.01	13.10.2014	Furban				km200_Define					Changing "if ($url =~ m/^((\d\d\d[01]\d\d2[0-4]\d25[0-5])\.){3}(\d\d\d[01]\d\d2[0-4]\d25[0-5])$/)" into "if ($url =~ m/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)"
#		1.02	20.10.2014	Sailor              km200_Encrypt       			Swapping over to Crypt::Rijndael
#		1.02	20.10.2014	Sailor              km200_Decrypt       			Swapping over to Crypt::Rijndael
#		1.03	21.10.2014	Sailor              All                 			Improving log3 functions for debugging
#		1.04	22.10.2014	Sailor              All                 			New function for get status and implementing export to Readings
#		1.05	23.10.2014	Sailor              km200_Define					Minimum interval changed to 20s since polling procedure lasts about 10s
#		1.05	23.10.2014	Sailor              km200_Get						New subroutine to receive individual data adhoc
#		1.06	25.10.2014	Sailor              km200_Set						First try
#		1.07	26.10.2014	Nobody0472          ALL           					Add FailSafe & Error Handling + KM50 + Interval in Definition
#		1.08    27.10.2014	Sailor				km200_GetData					Trying out whether 	"my $options = HTTP::Headers->new("Accept" => "application/json","User-Agent" => "TeleHeater/2.2.3", "agent" => "TeleHeater/2.2.3");" is the same as "$ua->agent('TeleHeater/2.2.3');"
#		1.08    27.10.2014	Sailor				km200_Define					Lot's of commenting in order to improve readability	:-)
#		1.08    27.10.2014	Sailor				km200_CompleteDataInit			Improvement of console output for easier debugging
#		1.08    27.10.2014	Sailor				=pod							First Issue of description added
#		1.09    27.10.2014	Sailor				km200_GetData					Try-out Failed and original code re enabled for: "Trying out whether "my $options = HTTP::Headers->new("Accept" => "application/json","User-Agent" => "TeleHeater/2.2.3", "agent" => "TeleHeater/2.2.3");" is the same as "$ua->agent('TeleHeater/2.2.3');""
#		1.09    27.10.2014	Nobody0472			km200_Attr						First Issue
#		1.09    27.10.2014	Sailor				km200_Attr						Adapted to double interval attributes "IntervalDynVal" and "IntervalStatVal"
#		1.09    27.10.2014	Sailor				km200_Define					Adapted to double interval attributes "IntervalDynVal" and "IntervalStatVal" and deleted interval of being imported from the define line.
#		1.09    27.10.2014	Sailor				km200_Define					Created list of known static services
#		1.09    27.10.2014	Sailor				km200_Define					Calculated a list of responding services which are not static = responding dynamic services
#		1.09    27.10.2014	Sailor				km200_CompleteDynData			Subroutine km200_CompleteData renamed to "km200_CompleteDynData" and only downloading responding dynamic services
#		1.09    27.10.2014	Sailor				km200_CompleteStatData			Subroutine "km200_CompleteStatData" created only downloading responding static services
#		1.10    28.10.2014	Sailor				km200_Define					Attribute check moved to km200_Attr
#		1.10    28.10.2014	Sailor				km200_Attr						Attribute check included
#		1.10    28.10.2014	Sailor				All								Clear-ups for comments and unused debug - print commands
#		1.10    28.10.2014	Sailor				km200_Define					Decoding of passwords with base64 implemented to avoid bare passwords in fhem.cfg
#		1.11    31.10.2014	Sailor				km200_Define					Added "/heatingCircuits/hc2" and subordinates 
#		1.11    31.10.2014	Sailor				km200_CompleteDynData			First try-outs with fork() command - FAILED! All fork() commands deleted
#		1.12	04.11.2014	Sailor	----------- Nearly all subroutines renamed! -----------------------------------------------------------------------------------------------------------------------
#		1.12    04.11.2014	Sailor				All								Integration of  HttpUtils_NonblockingGet(). Nearly all Subroutines renamed due to new functionality
#		1.13    05.11.2014	Sailor				All								Clearing up "print" and "log" command
#		1.13    05.11.2014	Sailor				km200_ParseHttpResponseInit		encode_utf8() command added to avoid crashes with "/heatSources/flameCurrent" or "/system/appliance/flameCurrent"
#		1.13    05.11.2014	Sailor				km200_ParseHttpResponseDyn		encode_utf8() command added to avoid crashes with "/heatSources/flameCurrent" or "/system/appliance/flameCurrent"
#		1.13    05.11.2014	Sailor				km200_ParseHttpResponseStat		encode_utf8() command added to avoid crashes with "/heatSources/flameCurrent" or "/system/appliance/flameCurrent"
#		1.13    05.11.2014	Sailor				km200_GetSingleService			New function used to obtain single value: HttpUtils_BlockingGet()
#		1.13    05.11.2014	Sailor				km200_PostSingleService			New function used to write  single value: HttpUtils_BlockingGet() (Yes, even called "get" in the end, it allows to write (POST) as well
#		1.14    06.11.2014	Sailor				km200_PostSingleService			Set value works! But only if no background download of dynamic or static values is active the same time
#		1.15    06.11.2014	Sailor				km200_Get						Creating proper hash out of array of responding services
#		1.15    07.11.2014	Sailor				km200_Set						Creating proper hash out of array of writeable services
#		1.15    07.11.2014	Sailor				km200_Initialize				Adding DbLog_splitFn
#		1.15    07.11.2014	Sailor				km200_DbLog_splitFn				First try-out. print function temporarily disabled
#		1.15    07.11.2014	Sailor				All								Adding some print-commands for debugging
#		1.15    07.11.2014	Sailor				km200_Set						Starting with blocking flags
#		1.16    09.11.2014	Sailor				km200_GetDynService				Additional Log for debugging added
#		1.16    09.11.2014	Sailor				km200_GetStatService			Additional Log for debugging added
#		1.17    10.11.2014	Sailor				km200_Initialize				Corrected DbLog entry to $hash->{DbLog_splitFn}  = "km200_DbLog_splitFn";
#		1.17    10.11.2014	Sailor				km200_Define					Password logging deleted. Too dangerous as soon a user posts its log seeking for help since gateway password cannot be changed
#		1.17    10.11.2014	Sailor				km200_Define					Adding $hash->{DELAYDYNVAL} and $hash->{DELAYSTATVAL} to delay start of timer
#		1.17    10.11.2014	Sailor				km200_Attr						Adding $hash->{DELAYDYNVAL} and $hash->{DELAYSTATVAL} to delay start of timer
#		1.17    10.11.2014	Sailor				km200_PostSingleService			Error handling 
#		1.17    10.11.2014	Sailor				km200_GetSingleService			Error handling 
#		1.17    10.11.2014	Sailor				km200_Define					Added additional STATE information
#		1.17    10.11.2014	Sailor				km200_GetDynService				Added additional STATE information
#		1.17    10.11.2014	Sailor				km200_GetStatService			Added additional STATE information
#		1.18    10.11.2014	Sailor				km200_Initialize				Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_Define					Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_Attr						Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_PostSingleService			Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_GetSingleService			Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_GetInitService			Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_GetDynService				Implementing polling time-out attribute in $hash
#		1.18    10.11.2014	Sailor				km200_GetStatService			Implementing polling time-out attribute in $hash
#		1.19    14.11.2014	Sailor				km200_GetInitService			Log Level for data not being available downgraded to Level 4		
#		1.19    14.11.2014	Sailor				km200_GetSingleService			Log Level for data not being available downgraded to Level 4
#		1.19    14.11.2014	Sailor				=pod							Description updated
#		1.20    14.11.2014	Sailor				All							    Implement Console-Printouts only if attribute "ConsoleMessage" is set
#		1.21    09.12.2014	Sailor				km200_GetDynService				Catching JSON parsing errors in order to prevent fhem crashes
#		1.21    09.12.2014	Sailor				km200_GetStatService			Catching JSON parsing errors in order to prevent fhem crashes
#		1.21    09.12.2014	Sailor				km200_GetInitService			Catching JSON parsing errors in order to prevent fhem crashes
#		1.21    09.12.2014	Sailor				km200_GetSingleService			Catching JSON parsing errors in order to prevent fhem crashes
#		1.22    09.12.2014	Sailor				All								Small format corrections
#		1.23    12.12.2014	Sailor				km200_Define					Swapping service for test of communication from "/system/brand" to "/gateway/DateTime"
#		1.24    12.12.2014	Sailor				km200_Initialize				Deactivating $hash->{DbLog_splitFn}
#		1.25    07.01.2015	Sailor				Comments						Updating comments based on created WIKI
#		1.25    07.01.2015	Sailor				km200_Attr						BugFix around ConsoleMessage Attribute
#		1.25    07.01.2015	Sailor				All								Log Message of verbose level 2 improved
#		1.25    07.01.2015	Sailor				=pod							Bugfix to be joined in commandref
########################################################################################################################


########################################################################################################################
# List of open Problems:
#
# *Many values in readings make no sense at all. 
#  SOLUTION: Manual disable values by user attribute that are of no use.
#
# *DbLog: X_DbLog_splitFn not completely implemented in order to hand over the units of the readings to DbLog database
#
########################################################################################################################

package main;

use strict;
use warnings;
use Blocking;
use Time::HiRes qw(gettimeofday sleep);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use base qw( Exporter );
use List::MoreUtils qw(first_index);
use MIME::Base64;
use LWP::UserAgent;
use JSON;
use Crypt::Rijndael;
use HttpUtils;
use Encode;
use constant false => 0;
use constant true  => 1;

sub km200_Define($$);
sub km200_Undefine($$);

###START###### Initialize module ##############################################################################START####
sub km200_Initialize($)
{
    my ($hash)  = @_;

    $hash->{STATE}           = "Init";
    $hash->{DefFn}           = "km200_Define";
    $hash->{UndefFn}         = "km200_Undefine";
    $hash->{SetFn}           = "km200_Set";
    $hash->{GetFn}           = "km200_Get";
    $hash->{AttrFn}          = "km200_Attr";
#	$hash->{DbLog_splitFn}   = "km200_DbLog_split";

    $hash->{AttrList}        = "do_not_notify:1,0 " .
						       "loglevel:0,1,2,3,4,5,6 " .
						       "IntervalDynVal " .
						       "IntervalStatVal " .
						       "PollingTimeout " .
							   "ConsoleMessage " .
						       $readingFnAttributes;
}
####END####### Initialize module ###############################################################################END#####


###START######  Activate module after module has been used via fhem command "define" ##########################START####
sub km200_Define($$)
{
	my ($hash, $def)            = @_;
	my @a						= split("[ \t][ \t]*", $def);
	my $name					= $a[0];
								 #$a[1] just contains the "km200" module name and we already know that! :-)
	my $url						= $a[2];
	my $km200_gateway_password	= $a[3];
	my $km200_private_password	= $a[4];
	my $ModuleVersion           = "v1.25";

	$hash->{NAME}				= $name;
	$hash->{STATE}              = "define";

	Log3 $name, 5, $name. " : km200 - Starting to define module with version: " . $ModuleVersion;
		
	###START###### Define provided services of gateway ########################################################START####
	my @KM200_AllServices = (
	"/",
	"/gateway",
	"/gateway/DateTime",
	"/gateway/instAccess",
	"/gateway/instWriteAccess",
	"/gateway/uuid",
	"/gateway/versionFirmware",
	"/gateway/versionHardware",

	"/heatingCircuits",
	"/heatingCircuits/hc1",
	"/heatingCircuits/hc1/activeSwitchProgram",
	"/heatingCircuits/hc1/actualSupplyTemperature",
	"/heatingCircuits/hc1/controlType",
	"/heatingCircuits/hc1/currentOpModeInfo",
	"/heatingCircuits/hc1/currentRoomSetpoint",
	"/heatingCircuits/hc1/designTemp",
	"/heatingCircuits/hc1/fastHeatupFactor",
	"/heatingCircuits/hc1/heatCurveMax",
	"/heatingCircuits/hc1/heatCurveMin",
	"/heatingCircuits/hc1/manualRoomSetpoint",
	"/heatingCircuits/hc1/operationMode",
	"/heatingCircuits/hc1/pumpModulation",
	"/heatingCircuits/hc1/roomInfluence",
	"/heatingCircuits/hc1/roomtemperature",
	"/heatingCircuits/hc1/roomTempOffset",
	"/heatingCircuits/hc1/setpointOptimization",
	"/heatingCircuits/hc1/solarInfluence",
	"/heatingCircuits/hc1/status",
	"/heatingCircuits/hc1/suWiSwitchMode",
	"/heatingCircuits/hc1/suWiThreshold",
	"/heatingCircuits/hc1/switchPrograms",
	"/heatingCircuits/hc1/temperatureLevels",
	"/heatingCircuits/hc1/temperatureRoomSetpoint",
	"/heatingCircuits/hc1/temporaryRoomSetpoint",
	
	"/heatingCircuits/hc2",
	"/heatingCircuits/hc2/activeSwitchProgram",
	"/heatingCircuits/hc2/actualSupplyTemperature",
	"/heatingCircuits/hc2/controlType",
	"/heatingCircuits/hc2/currentOpModeInfo",
	"/heatingCircuits/hc2/currentRoomSetpoint",
	"/heatingCircuits/hc2/designTemp",
	"/heatingCircuits/hc2/fastHeatupFactor",
	"/heatingCircuits/hc2/heatCurveMax",
	"/heatingCircuits/hc2/heatCurveMin",
	"/heatingCircuits/hc2/manualRoomSetpoint",
	"/heatingCircuits/hc2/operationMode",
	"/heatingCircuits/hc2/pumpModulation",
	"/heatingCircuits/hc2/roomInfluence",
	"/heatingCircuits/hc2/roomtemperature",
	"/heatingCircuits/hc2/roomTempOffset",
	"/heatingCircuits/hc2/setpointOptimization",
	"/heatingCircuits/hc2/solarInfluence",
	"/heatingCircuits/hc2/status",
	"/heatingCircuits/hc2/suWiSwitchMode",
	"/heatingCircuits/hc2/suWiThreshold",
	"/heatingCircuits/hc2/switchPrograms",
	"/heatingCircuits/hc2/temperatureLevels",
	"/heatingCircuits/hc2/temperatureRoomSetpoint",
	"/heatingCircuits/hc2/temporaryRoomSetpoint",

	"/heatSources",
	"/heatSources/actualCHPower",
	"/heatSources/actualDHWPower",
	"/heatSources/actualPower",
	"/heatSources/actualsupplytemperature",
	"/heatSources/ChimneySweeper",
	"/heatSources/CHpumpModulation",
	"/heatSources/flameCurrent",
	"/heatSources/flameStatus",
	"/heatSources/gasAirPressure",
	"/heatSources/nominalCHPower",
	"/heatSources/nominalDHWPower",
	"/heatSources/numberOfStarts",
	"/heatSources/powerSetpoint",
	"/heatSources/powerSetpoint",
	"/heatSources/returnTemperature",
	"/heatSources/systemPressure",
	"/heatSources/workingTime",

	"/heatSources/hs1/energyReservoir",
	"/heatSources/hs1/reservoirAlert",
	"/heatSources/hs1/nominalFuelConsumption",
	"/heatSources/hs1/fuelConsmptCorrFactor",
	"/heatSources/hs1/actualModulation",
	"/heatSources/hs1/actualPower",
	"/heatSources/hs1/fuel",
	
	"/notifications",

	"/recordings",
	"/recordings/heatingCircuits",
	"/recordings/heatingCircuits/hc1",
	"/recordings/heatingCircuits/hc1/roomtemperature",
	"/recordings/heatSources",
	"/recordings/heatSources/actualCHPower",
	"/recordings/heatSources/actualDHWPower",
	"/recordings/heatSources/actualPower",
	"/recordings/system",
	"/recordings/system/heatSources",
	"/recordings/system/heatSources/hs1",
	"/recordings/system/heatSources/hs1/actualPower",
	"/recordings/system/sensors",
	"/recordings/system/sensors/temperatures",
	"/recordings/system/sensors/temperatures/outdoor_t1",

	"/solarCircuits",
	"/solarCircuits/sc1/",
	"/solarCircuits/sc1/collectorTemperature",
	"/solarCircuits/sc1/pumpModulation",
	"/solarCircuits/sc1/solarYield",
	"/solarCircuits/sc1/status",

	"/system",
	"/system/appliance",
	"/system/appliance/actualPower",
	"/system/appliance/actualSupplyTemperature",
	"/system/appliance/ChimneySweeper",
	"/system/appliance/CHpumpModulation",
	"/system/appliance/flameCurrent",
	"/system/appliance/gasAirPressure",
	"/system/appliance/nominalBurnerLoad",
	"/system/appliance/numberOfStarts",
	"/system/appliance/powerSetpoint",
	"/system/appliance/systemPressure",
	"/system/appliance/workingTime",

	"/system/brand",
	"/system/bus",
	"/system/healthStatus",

	"/system/heatSources/",
	"/system/heatSources/hs1",
	"/system/heatSources/hs1/actualModulation",
	"/system/heatSources/hs1/actualPower",
	"/system/heatSources/hs1/energyReservoir",
	"/system/heatSources/hs1/fuel",
	"/system/heatSources/hs1/fuel/density",
	"/system/heatSources/hs1/fuelConsmptCorrFactor",
	"/system/heatSources/hs1/nominalFuelConsumption",
	"/system/heatSources/hs1/reservoirAlert",

	"/system/info",

	"/system/minOutdoorTemp",

	"/system/sensors",
	"/system/sensors/temperatures",
	"/system/sensors/temperatures/chimney",
	"/system/sensors/temperatures/hotWater_t1",
	"/system/sensors/temperatures/hotWater_t2",
	"/system/sensors/temperatures/outdoor_t1",
	"/system/sensors/temperatures/return",
	"/system/sensors/temperatures/supply_t1",
	"/system/sensors/temperatures/supply_t1_setpoint",
	"/system/sensors/temperatures/switch",

	"/system/systemType"
	);
	
	my @KM200_StatServices = (
	"/gateway/uuid",
	"/gateway/instAccess",
	"/gateway/versionFirmware",
	"/gateway/versionHardware",
	"/system/brand",
	"/system/bus",
	"/system/info",
	"/system/systemType"
	);
	####END####### Define provided services of gateway #########################################################END#####

	
    ###START### Check whether all variables are available #####################################################START####
	if (int(@a) == 5) 
	{
		###START### Check whether IPv4 address is valid
		if ($url =~ m/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/)
		{
			Log3 $name, 5, $name. " : km200 - IPv4-address is valid                 : " . $url;
		}
		else
		{
			return $name .": Error - IPv4 address is not valid \n Please use \"define <devicename> km200 <IPv4-address> <interval/[s]> <GatewayPassword> <PrivatePassword>\" instead";
		}
		####END#### Check whether IPv4 address is valid	

		
		###START### Check whether gateway password is base64 encoded or bare, has the right length and delete "-" if required
		my $PasswordEncrypted = false;
		my $EvalPassWord = $km200_gateway_password;
		$EvalPassWord =~ tr/-//d;

		if ( length($EvalPassWord) == 16)
		{
				$km200_gateway_password = $EvalPassWord;
				Log3 $name, 5, $name. " : km200 - Provided GatewayPassword provided as bareword has the correct length at least.";		
		}
		else # Check whether the password is eventually base64 encoded 
		{
		    # Remove additional encoding with base64
			my $decryptData = decode_base64($km200_gateway_password);
			$decryptData =~ tr/-//d;
			$decryptData =~ s/\r|\n//g;
			if ( length($decryptData) == 16)
			{
				$km200_gateway_password = $decryptData;
				$PasswordEncrypted = true;
				Log3 $name, 5, $name. " : km200 - Provided GatewayPassword encoded with base64 has the correct length at least.";
			}
			else
			{
				return $name .": Error - GatewayPassword does not have the correct length.\n". 
							  "          Please enter gateway password in the format of \"aaaabbbbccccdddd\" or \"aaaa-bbbb-cccc-dddd\"\n". 
							  "          You may encode your password with base64 first, in order to prevent bare passwords in fhem.cfg.\n".
							  "          If you choose to encrypt your gateway password with base64, you also must encrypt your private password the same way\n"; 

				Log3 $name, 3, $name. " : km200 - Provided Gateway Password does not follow the specifications";
			}
		}
		####END#### Check whether gateway password has the right length and delete "-" if required

		###START### Check whether private password is available and decode it with base64 if encoding is used
		if ($PasswordEncrypted == true)
		{
			my $decryptData = decode_base64($km200_private_password);
			$decryptData =~ s/\r|\n//g;
			if (length($decryptData) > 0)
			{
				$km200_private_password = $decryptData;
				Log3 $name, 5, $name. " : km200 - Provided PrivatePassword exists at least";
			}
			else
			{
				return $name .": Error - PrivatePassword does not have the minimum length.\n".
							  "          You may encode your password with base64 first, in order to prevent bare passwords in fhem.cfg.\n".
							  "          If you choose to encrypt your private password with base64, you also must encrypt your gateway password the same way\n"; 
			}
		}
		else # If private password is provided as bare word
		{
			if (length($km200_private_password) > 0)
			{
					Log3 $name, 5, $name. " : km200 - Provided PrivatePassword exists at least";		
			}
			else
			{
				return $name .": Error - PrivatePassword has not been provided.\n".
							  "          You may encode your password with base64 first, in order to prevent bare passwords in fhem.cfg.\n".
							  "          If you choose to encrypt your private password with base64, you also must encrypt your gateway password the same way\n"; 
				Log3 $name, 3, $name. " : km200 - Provided Private Password does not follow the specifications";
		  }
		}
		####END#### Check whether private password is available and decode it with base64 if encoding is used
	}
	else
	{
	    return $name .": km200 - Error - Not enough parameter provided." . "\n" . "Gateway IPv4 address, Gateway and Private Passwords must be provided" ."\n". "Please use \"define <devicename> km200 <IPv4-address> <GatewayPassword> <PrivatePassword>\" instead";
	}
	####END#### Check whether all variables are available ######################################################END#####

	
	###START###### Create the secret SALT of the MD5-Hash for AES-encoding ####################################START####
	my $Buderus_MD5Salt = pack(
	'C*',
	0x86, 0x78, 0x45, 0xe9, 0x7c, 0x4e, 0x29, 0xdc,
	0xe5, 0x22, 0xb9, 0xa7, 0xd3, 0xa3, 0xe0, 0x7b,
	0x15, 0x2b, 0xff, 0xad, 0xdd, 0xbe, 0xd7, 0xf5,
	0xff, 0xd8, 0x42, 0xe9, 0x89, 0x5a, 0xd1, 0xe4
	);
	####END####### Create the secret SALT of the MD5-Hash for AES-encoding #####################################END#####
	

	###START###### Create keys with MD5 #######################################################################START####
	# Copy Salt
	my $km200_crypt_md5_salt = $Buderus_MD5Salt;

	# First half of the key: MD5 of (km200GatePassword . Salt)
	my $key_1 = md5($km200_gateway_password . $km200_crypt_md5_salt);  
	  
	# Second half of the key: - Initial: MD5 of ( Salt)
	my $key_2_initial = md5($km200_crypt_md5_salt);

	# Second half of the key: -  private: MD5 of ( Salt . km200PrivatePassword)
	my $key_2_private = md5($km200_crypt_md5_salt . $km200_private_password);

	# Create keys
	my $km200_crypt_key_initial = ($key_1 . $key_2_initial);
	my $km200_crypt_key_private = ($key_1 . $key_2_private);
	####END####### Create keys with MD5 #########################################################################END#####
  
  
	###START###### Writing values to global hash ###############################################################START####
	  $hash->{NAME}                             = $name;
	  $hash->{URL}                              = $url;
      $hash->{VERSION}                          = $ModuleVersion;
	  $hash->{INTERVALDYNVAL}                   = 60;
	  $hash->{DELAYDYNVAL}                      = 60;
	  $hash->{INTERVALSTATVAL}                  = 3600;
	  $hash->{DELAYSTATVAL}                     = 120;
	  $hash->{DISABLESTATVALPOLLING}            = false;
	  $hash->{POLLINGTIMEOUT}                   = 5;
	  $hash->{CONSOLEMESSAGE}					= false;
	  $hash->{temp}{ServiceCounterInit}         = 0;
	  $hash->{temp}{ServiceCounterDyn}          = 0;
	  $hash->{temp}{ServiceCounterStat}         = 0;
	  $hash->{status}{FlagInitRequest}          = false;
	  $hash->{status}{FlagGetRequest}           = false;
	  $hash->{status}{FlagSetRequest}           = false;
	  $hash->{status}{FlagDynRequest}           = false;
	  $hash->{status}{FlagStatRequest}          = false;
	  $hash->{Secret}{CRYPTKEYPRIVATE}          = $km200_crypt_key_private;
	  $hash->{Secret}{CRYPTKEYINITIAL}          = $km200_crypt_key_initial;
	@{$hash->{Secret}{KM200ALLSERVICES}}        = @KM200_AllServices;
	@{$hash->{Secret}{KM200STATSERVICES}}       = @KM200_StatServices;
	@{$hash->{Secret}{KM200RESPONDINGSERVICES}} = ();
	@{$hash->{Secret}{KM200WRITEABLESERVICES}}  = ();
	####END####### Writing values to global hash ################################################################END#####


	###START###### For Debugging purpose only ##################################################################START####  
	Log3 $name, 5, $name. " : km200 - Define H                              : " .$hash;
	Log3 $name, 5, $name. " : km200 - Define D                              : " .$def;
	Log3 $name, 5, $name. " : km200 - Define A                              : " .@a;
	Log3 $name, 5, $name. " : km200 - Define Name                           : " .$name;
	Log3 $name, 5, $name. " : km200 - Define Adr                            : " .$url;
	####END####### For Debugging purpose only ###################################################################END#####

	
	###START###### Check whether communication to the physical unit is possible ################################START####
	my $Km200Info ="";
	$hash->{temp}{service} = "/gateway/DateTime";
	$Km200Info = km200_GetSingleService($hash);
	
	if ($Km200Info eq "ERROR") 
	{
		$Km200Info = $hash->{temp}{TransferValue};
		$hash->{temp}{TransferValue} = "";
	}

	if ($Km200Info eq "ERROR") 
	{
		## Communication with Gateway WRONG !! ##
	
		$hash->{STATE}="Error - No Communication";
		return ($name .": km200 - ERROR - The communication between fhem and the Buderus KM200 failed! \n". 
		               "                  Please check physical connection, IP-address and  passwords! \n");
	} 
	elsif ($Km200Info eq "SERVICE NOT AVAILABLE") 
	{
		Log3 $name, 5, $name. " : km200 -  /gateway/DateTime             : NOT AVAILABLE";			## Communication OK but service not available ##
	} 
	else 
	{
		Log3 $name, 5, $name. " : km200 - /gateway/DateTime              : " .$Km200Info->{value};	## Communication OK and service is available ##
	}
	####END####### Check whether communication to the physical unit is possible ################################END#####
	

	###START###### Get complete set of responding services and first time readings ############################START####
	if ($hash->{CONSOLEMESSAGE} == true) {print("\n");}
	km200_GetInitService($hash);
	####END####### Get complete set of responding services and first time readings #############################END#####
	

	###START###### Initiate the timer for continuous polling of dynamical values from KM200 but wait 60s ######START####
	InternalTimer(gettimeofday()+$hash->{DELAYDYNVAL}, "km200_GetDynService", $hash, 0);
	Log3 $name, 5, $name. " : km200 - Internal timer for dynamic values prepared with default interval.";
	####END####### Initiate the timer for continuous polling of dynamical values from KM200 ####################END#####

	
	###START###### Initiate the timer for continuous polling of static values from KM200 but wait 120s ########START####
	InternalTimer(gettimeofday()+$hash->{DELAYSTATVAL}, "km200_GetStatService", $hash, 0);
	Log3 $name, 5, $name. " : km200 - Internal timer for static values prepared with default interval.";
	####END####### Initiate the timer for continuous polling of static values from KM200 #######################END#####
	
	
	###START###### Set status of km200 fhem module to Initialized #############################################START####
	$hash->{STATE}="Initialized";
	####END####### Set status of km200 fhem module to Initialized ##############################################END#####
	
	return undef;
}
####END####### Activate module after module has been used via fhem command "define" ############################END#####


###START###### To bind unit of value to DbLog entries #########################################################START####
### This Function needs to be completed later
sub km200_DbLog_split($)
{
	my ($event) = @_;
	my ($reading, $value, $unit);

#	print("km200_DbLog_splitFn - Test for event:" . $event ."\n");
	
    return ($reading, $value, $unit);
}
####END####### To bind unit of value to DbLog entries ##########################################################END#####


###START###### Deactivate module module after "undefine" command by fhem ######################################START####
sub km200_Undefine($$)
{
	my ($hash, $def)  = @_;
	my $name = $hash->{NAME};	
	my $url  = $hash->{URL};

  	# Stop the internal timer for this module
	RemoveInternalTimer($hash);

	Log3 $name, 3, $name. " - km200 has been undefined. The KM unit at $url will no longer polled.";

	return undef;
}
####END####### Deactivate module module after "undefine" command by fhem #######################################END#####


###START###### Handle attributes after changes via fhem GUI ###################################################START####
sub km200_Attr(@)
{
	my @a                      = @_;
	my $name                   = $a[1];
	my $hash                   = $defs{$name};
	my $DisableStatValPolling  = $hash->{DISABLESTATVALPOLLING};
	my $IntervalDynVal         = $hash->{INTERVALDYNVAL};
	my $IntervalStatVal        = $hash->{INTERVALSTATVAL};
	my $DelayDynVal            = $hash->{DELAYDYNVAL};
	my $DelayStatVal           = $hash->{DELAYSTATVAL};

	### Check whether dynamic interval attribute has been provided
	if($a[2] eq "IntervalDynVal") 
	{

		$IntervalDynVal = $a[3];
		###START### Check whether polling interval is not too short
		if ($IntervalDynVal > 19)
		{
			$hash->{INTERVALDYNVAL} = $IntervalDynVal;
			Log3 $name, 5, $name. " : km200 - IntervalDynVal set to attribute value:" . $IntervalDynVal ." s";
		}
		else
		{
			return $name .": Error - Gateway interval for IntervalDynVal too small - server response time longer than defined interval, please use something >=20, default is 90";
		}
		####END#### Check whether polling interval is not too short
	}
	### Check whether static interval attribute has been provided
	elsif($a[2] eq "IntervalStatVal") 
	{
		$IntervalStatVal = $a[3];

		if ($IntervalStatVal == 0) ### Check whether statical values supposed to be polled at all. The attribute "IntervalStatVal" set to "0" means no polling for statical values.
		{
			$DisableStatValPolling = true;
			$hash->{DISABLESTATVALPOLLING} = $DisableStatValPolling;
			Log3 $name, 5, $name. " : km200 - Polling for static values diabled";
		}
		else
		{
			###START### Check whether polling interval is not too short	
			if ($IntervalStatVal > 19)
			{
				$DisableStatValPolling = false;
				$hash->{INTERVALSTATVAL} = $IntervalStatVal;
				Log3 $name, 5, $name. " : km200 - IntervalStatVal set to attribute value:" . $IntervalStatVal ." s";
			}
			else
			{
				return $name .": Error - Gateway interval for IntervalStatVal too small - server response time longer than defined interval, please use something >=20, default is 3600";
			}
			####END#### Check whether polling interval is not too short	
		}
	}
	### Check whether room attribute have been provided
	elsif($a[2] eq "room") 
	{
		### Do nothing
	}
	### Check whether polling timeout attribute has been provided
	elsif($a[2] eq "PollingTimeout") 
	{
		###START### Check whether timeout is not too short
		if ($a[3] >= 5)
		{
			$hash->{POLLINGTIMEOUT} = $a[3];
			Log3 $name, 5, $name. " : km200 - Polling timeout set to attribute value:" . $a[3] ." s";
		}
		else
		{
			Log3 $name, 5, $name. " : km200 - Error - Gateway polling timeout attribute too small: " . $a[3] ." s";
			return $name .": Error - Gateway polling timeout attribute is too small - server response time is 5s minimum, default is 5";
		}
		####END#### Check whether timeout is not too short
	}
	### Check whether console printout attribute has been provided
	elsif($a[2] eq "ConsoleMessage") 
	{
		### If messages on console shall be visible
		if ($a[3] == 1)
		{
			$hash->{CONSOLEMESSAGE}	= true;
			Log3 $name, 5, $name. " : km200 - Console printouts enabled";
		}
		### If messages on console shall NOT be visible
		else
		{
			$hash->{CONSOLEMESSAGE}	= false;
			Log3 $name, 5, $name. " : km200 - Console printouts disabled";
		}
	}
	### If no attributes of the above known ones have been selected
	else
	{
		Log3 $name, 5, $name. " : km200 - Unknown attribute: $a[2]";
	}


	###START### Stop the current timer
	RemoveInternalTimer($hash);
	####END#### Stop the current timer

	
	###START###### Initiate the timer for continuous polling of dynamical values from KM200 ###################START####
	InternalTimer(gettimeofday()+$DelayDynVal, "km200_GetDynService", $hash, 0);
	Log3 $name, 4, $name. " : km200 - Define: InternalTimer for dynamic values started with interval of: ".$IntervalDynVal;
	####END####### Initiate the timer for continuous polling of dynamical values from KM200 ####################END#####

	
	###START###### Initiate the timer for continuous polling of static values from KM200 ######################START####
	if ($DisableStatValPolling == false)
	{
		InternalTimer(gettimeofday()+$DelayStatVal, "km200_GetStatService", $hash, 0);
		Log3 $name, 4, $name. " : km200 - Define: InternalTimer for static values started with interval of: ".$IntervalStatVal;
	}
	else
	{
		Log3 $name, 4, $name. " : km200 - Define: No InternalTimer for static values since polling disabled by \"attr IntervalStatVal 0\" in fhem.cfg ";
	}
	####END####### Initiate the timer for continuous polling of static values from KM200 #######################END#####
	
	return undef;
}
####END####### Handle attributes after changes via fhem GUI ####################################################END#####


###START###### Obtain value after "get" command by fhem #######################################################START####
sub km200_Get($@)
{
	my ( $hash, @a ) = @_;
	
	### If not enough arguments have been provided
	if ( @a < 2 )
	{
		return "\"get km200\" needs at least one argument";
	}
		
	my $name = shift @a;
	my $opt  = shift @a;
	my %km200_gets;
	my $ReturnValue;
	
	### Get the list of possible services and create a hash out of it
	my @RespondingServices = @{$hash->{Secret}{KM200RESPONDINGSERVICES}};

	foreach my $item(@RespondingServices) 	
	{
		$km200_gets{$item} = ("1");
	}
	
	### If service chosen in GUI does not exist
	if(!$km200_gets{$opt}) 
	{
		my @cList = keys %km200_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
	### Save chosen service into hash
	$hash->{temp}{service} = $opt;

	### Block other scheduled and unscheduled routines
	$hash->{status}{FlagGetRequest} = true;

	### Console outputs for debugging purposes
	if ($hash->{CONSOLEMESSAGE} == true) {print("Obtaining value of $opt \n");}
	
	### Read service-hash
	my $ReturnHash = km200_GetSingleService($hash);

	### De-block other scheduled and unscheduled routines
	$hash->{status}{FlagGetRequest} = false;

	### Extract value
	$ReturnValue = $ReturnHash->{value};	
	
	### Delete temporary value
	$hash->{temp}{service} = "";
	
	### Return value
	return($ReturnValue);
}
####END####### Obtain value after "get" command by fhem ########################################################END#####


###START###### Manipulate service after "set" command by fhem #################################################START####
sub km200_Set($@)
{
	my ( $hash, @a ) = @_;
	
	### If not enough arguments have been provided
	if ( @a < 2 )
	{
		return "\"set km200\" needs at least one argument";
	}
		
	my $name = shift @a;
	my $opt  = shift @a;
	my $value = join("", @a);
	my %km200_sets;

	### Get the list of possible services and create a hash out of it
	my @WriteableServices = @{$hash->{Secret}{KM200WRITEABLESERVICES}};

	foreach my $item(@WriteableServices) 	
	{
		$km200_sets{$item} = ("1");
	}
	
	### If service chosen in GUI does not exist
	if(!$km200_sets{$opt}) 
	{
		my @cList = keys %km200_sets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}

	### Save chosen service and value into hash
	$hash->{temp}{service}  = $opt;
	$hash->{temp}{postdata} = $value;
	
	### Console outputs for debugging purposes
	if ($hash->{CONSOLEMESSAGE} == true) {print("Writing $opt with value: $value\n");}

	### Call set sub
	km200_PostSingleService($hash);
	km200_PostSingleService($hash);

	### Return value
	my $ReturnValue = "The service " . $opt . " has been changed to: " . $value;
	return($ReturnValue);
}
####END####### Manipulate service after "Set" command by fhem ##################################################END#####


###START####### Repeats "string" for "count" times ############################################################START####
sub str_repeat($$)
{
    my $string = $_[0];
    my $count  = $_[1];
    return(${string}x${count});
}
####END######## Repeats "string" for "count" times #############################################################END#####


###START###### Subroutine Encrypt Data ########################################################################START####
sub km200_Encrypt($)
{
	my ($hash, $def)            = @_;

	my $km200_crypt_key_private = $hash->{Secret}{CRYPTKEYPRIVATE};
	my $name                    = $hash->{NAME};
	my $encryptData             = $hash->{temp}{jsoncontent};

    # Create Rijndael encryption object
    my $cipher = Crypt::Rijndael->new($km200_crypt_key_private, Crypt::Rijndael::MODE_ECB() );

    # Get blocksize and add PKCS #7 padding
    my $blocksize =  $cipher->blocksize();
    my $encrypt_padchar = $blocksize - ( length( $encryptData ) % $blocksize );
    $encryptData .= str_repeat( chr( $encrypt_padchar ), $encrypt_padchar );

	# Do the encryption
    my $ciphertext = $cipher->encrypt( $encryptData );

	# Do additional encoding with base64
    $ciphertext = encode_base64($ciphertext);
   
    # Return the encoded text
    return($ciphertext);
}
####END####### Subroutine Encrypt Data #########################################################################END#####


###START###### Subroutine Decrypt Data ########################################################################START####
sub km200_Decrypt($)
{
	my ($hash, $def)            = @_;

	my $km200_crypt_key_private = $hash->{Secret}{CRYPTKEYPRIVATE};
	my $name                    = $hash->{NAME};
	my $decryptData             = $hash->{temp}{decodedcontent};

    # Remove additional encoding with base64
    $decryptData = decode_base64($decryptData);

    # Create Rijndael decryption object and do the decryption
    my $cipher = Crypt::Rijndael->new($km200_crypt_key_private, Crypt::Rijndael::MODE_ECB() );
    my $deciphertext = $cipher->decrypt( $decryptData );

    # Remove zero padding
    $deciphertext =~ s/\x00+$//;

    # Remove PKCS #7 padding   
    my $decipher_len = length($deciphertext);
    my $decipher_padchar = ord(substr($deciphertext,($decipher_len - 1),1));
   
    my $i = 0;
    
    for ( $i = 0; $i < $decipher_padchar ; $i++ )
    {
        if ( $decipher_padchar != ord( substr($deciphertext,($decipher_len - $i - 1),1)))
        {
            last;
        }
    }
    
    # Return decrypted text
    if ( $i != $decipher_padchar )
    {
		### Log entries for debugging purposes
		Log3 $name, 5, $name. " : km200 - decryptData1 - decipher_len           : " .$decipher_len;
		$deciphertext =~ s/\x00+$//;
		Log3 $name, 5, $name. " : km200 - decryptData1 - deciphertext           : " .$deciphertext;
		### Log entries for debugging purposes
        return $deciphertext;
    }
    
	else
    {
		$deciphertext = substr($deciphertext,0,$decipher_len - $decipher_padchar);
		### Log entries for debugging purposes
		Log3 $name, 5, $name. " : km200 - decryptData2 - decipher_len           : " .$decipher_len;
		$deciphertext =~ s/\x00+$//;
		Log3 $name, 5, $name. " : km200 - decryptData2 - deciphertext           : " .$deciphertext;
		### Log entries for debugging purposes
        return $deciphertext;
    }
}
####END####### Subroutine Decrypt Data #########################################################################END#####


###START###### Subroutine set individual data value ###########################################################START####
sub km200_PostSingleService($)
{
	my ($hash, $def)                = @_;

	my $Service                     = $hash->{temp}{service};
	my $km200_gateway_host          = $hash->{URL} ;
	my $name                        = $hash->{NAME} ;
	my $PollingTimeout              = $hash->{POLLINGTIMEOUT};
	my $err;
	my $data;
	my $json;
	my $JsonContent;

	
	my $url ="http://" . $km200_gateway_host . $Service;
	
	### Manipulate the value
	$json->{value} = $hash->{temp}{postdata};
	
	### Encode as json
	$JsonContent = encode_json($json);
	
	### Encrypt 
	$hash->{temp}{jsoncontent} = $JsonContent;
	$data = km200_Encrypt($hash);

	
	### Create parameter set for HttpUtils_BlockingGet
	my $param = {
					url        => $url,
					timeout    => $PollingTimeout,
					data       => $data,
					method     => "POST",
					header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",
				};
				
	### Write value with HttpUtils_BlockingGet
	($err, $data) = HttpUtils_BlockingGet($param);


	### If error messsage has been returned
	if($err ne "") 
	{
		Log3 $name, 2, $name . " - ERROR: $err";
		if ($hash->{CONSOLEMESSAGE} == true) {print("km200_PostSingleService - Error: $err\n");}
		return "ERROR";	
	}
	else
	{
		### ReRead the whole json hash by read-out the value
		$json = km200_GetSingleService($hash);	
		
		### Log entries for debugging purposes
		Log3 $name, 5, $name. " : km200_PostSingleService   : " .$json;
		### Log entries for debugging purposes
		$hash->{status}{FlagSetRequest} = false;
		
		return $json;
	}
}
####END####### Subroutine set individual data value ############################################################END##### 


###START###### Subroutine get individual data value ###########################################################START####
sub km200_GetSingleService($)
{
	my ($hash, $def)            	= @_;

	my $Service                 	= $hash->{temp}{service};
	my $km200_gateway_host      	= $hash->{URL};
	my $name                    	= $hash->{NAME};
	my $PollingTimeout              = $hash->{POLLINGTIMEOUT};
	my $err;
	my $data;
	my $json;
	
	my $url ="http://" . $km200_gateway_host . $Service;

	my $param = {
					url        => $url,
					timeout    => $PollingTimeout,
					method     => "GET",
					header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",
				};

	($err, $data) = HttpUtils_BlockingGet($param);

	if($err ne "") 
	{
		Log3 $name, 2, $name . " : ERROR: Service: ".$Service. ": No proper Communication with Gateway: " .$err;
		if ($hash->{CONSOLEMESSAGE} == true) {print("km200_GetSingleService ERROR: $err\n");}
		return "ERROR";
	}
	else
	{
		$hash->{temp}{decodedcontent} = $data;
		my $decodedContent = km200_Decrypt($hash);

		if ($decodedContent ne "")
		{
			eval 
			{
				$json = decode_json(encode_utf8($decodedContent));
				1;
			}
			or do 
			{
			Log3 $name, 5, $name. " : km200_GetSingleService - Data cannot be parsed by JSON on km200 for http://" . $param->{url};
			if ($hash->{CONSOLEMESSAGE} == true) {print("Data not parseable on km200 for " . $param->{url} . "\n");}
			};

			if( exists $json -> {"value"})
			{
				my $JsonId         = $json->{id};
				my $JsonType       = $json->{type};
				my $JsonValue      = $json->{value};

				### Write reading for fhem
				readingsSingleUpdate( $hash, $JsonId, $JsonValue, 1);
				### Write reading for fhem
			}	
			else
			{
				### Log entries for debugging purposes
				Log3 $name, 4, $name. " : km200_GetSingleService - value not found for:" .$Service;
				### Log entries for debugging purposes
			}
		}
		else 
		{
			Log3 $name, 4, $name. " : km200_GetSingleService: ". $Service . " NOT available";
			if ($hash->{CONSOLEMESSAGE} == true) {print "The following Service CANNOT be read              : $Service \n";}

		}
		
		### Log entries for debugging purposes
		Log3 $name, 5, $name. " : km200_GetSingleService        : " .$json;
		### Log entries for debugging purposes

		$hash->{status}{FlagGetRequest} = false;
		
		return $json;
	}
}
####END####### Subroutine get individual data value ############################################################END#####


###START###### Subroutine initial contact of services via HttpUtils ###########################################START####
sub km200_GetInitService($)
{
	my ($hash, $def)                 = @_;
	my $km200_gateway_host           =   $hash->{URL} ;
	my $name                         =   $hash->{NAME} ;
	$hash->{status}{FlagInitRequest} = true;
	my @KM200_InitServices           = @{$hash->{Secret}{KM200ALLSERVICES}};
	my $ServiceCounterInit           = $hash->{temp}{ServiceCounterInit};
	my $PollingTimeout               = $hash->{POLLINGTIMEOUT};
	my $Service                      = $KM200_InitServices[$ServiceCounterInit];

	my $url ="http://" . $km200_gateway_host . $Service;

	my $param = {
					url        => $url,
					timeout    => $PollingTimeout,
					hash       => $hash,
					method     => "GET",
					header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",
					callback   =>  \&km200_ParseHttpResponseInit
				};

	HttpUtils_NonblockingGet($param);
}
####END####### Subroutine initial contact of services via HttpUtils ############################################END#####


###START###### Subroutine to download complete initial data set from gateway ##################################START####
# For all existing known services try reading the respective values from gateway
sub km200_ParseHttpResponseInit($)
{
    my ($param, $err, $data)     = @_;
    my $hash                     =   $param->{hash};
    my $name                     =   $hash ->{NAME};
	my $ServiceCounterInit       =   $hash ->{temp}{ServiceCounterInit};
	my @KM200_RespondingServices = @{$hash ->{Secret}{KM200RESPONDINGSERVICES}};
	my @KM200_WriteableServices  = @{$hash ->{Secret}{KM200WRITEABLESERVICES}};
	my @KM200_InitServices       = @{$hash ->{Secret}{KM200ALLSERVICES}};	
	my $NumberInitServices       = @KM200_InitServices;
	my $Service                  = $KM200_InitServices[$ServiceCounterInit];
	my $json;	
	
	
	### Log entries for debugging purposes
	Log3 $name, 5, $name. " : km200_ParseHttpResponseInit: Try to parse     : " .$Service;
	### Log entries for debugging purposes

	
	if($err ne "") 
	{
		Log3 $name, 2, $name . " : ERROR: Service: ".$Service. ": No proper Communication with Gateway: " .$err;
		if ($hash->{CONSOLEMESSAGE} == true) {print("km200_ParseHttpResponseInit ERROR: $err\n");}
		return "ERROR";	
	}

	$hash->{temp}{decodedcontent} = $data;
	my $decodedContent = km200_Decrypt($hash);
	if ($decodedContent ne "")
	{	
		eval 
		{
			$json = decode_json(encode_utf8($decodedContent));
			1;
		}
		or do 
		{
			Log3 $name, 4, $name. " : km200_ParseHttpResponseInit: ". $Service . " CANNOT be parsed";
			if ($hash->{CONSOLEMESSAGE} == true) {print "The following Service CANNOT be parsed by JSON    : $Service \n";}
		};

		if( exists $json -> {"value"})
		{
			my $JsonId         = $json->{id};
			my $JsonType       = $json->{type};
			my $JsonValue      = $json->{value};

			### Log entries for debugging purposes
			Log3 $name, 4, $name. " : km200_ParseHttpResponseInit: value found for  : " .$Service;
			Log3 $name, 5, $name. " : km200_ParseHttpResponseInit: id               : " .$JsonId;
			Log3 $name, 5, $name. " : km200_ParseHttpResponseInit: value            : " .$JsonValue;
			### Log entries for debugging purposes

			### Add service to the list of responding services
			push (@KM200_RespondingServices, $Service);
			### Add service to the list of responding services

			### Write reading for fhem
			readingsSingleUpdate( $hash, $JsonId, $JsonValue, 1);
			### Write reading for fhem

			if ($hash->{CONSOLEMESSAGE} == true) {print "The following Service can be read";}

			
			### Check whether service is writeable and write name of service in array
			if ($json->{writeable} == 1)
			{
				if ($hash->{CONSOLEMESSAGE} == true) {print " and is writeable";}
				push (@KM200_WriteableServices, $Service);
			}
			else
			{
				# Do nothing
				if ($hash->{CONSOLEMESSAGE} == true) {print "                 ";}
			}
			### Check whether service is writeable and write name of service in array
			
			if ($hash->{CONSOLEMESSAGE} == true) {print ": $JsonId \n";}
		}	
		else
		{
			### Log entries for debugging purposes
			Log3 $name, 4, $name. " : km200_ParseHttpResponseInit - value not found for:" .$Service;
			### Log entries for debugging purposes
		}
	}
	else 
	{
		Log3 $name, 4, $name. " : km200_ParseHttpResponseInit: ". $Service . " NOT available";
		if ($hash->{CONSOLEMESSAGE} == true) {print "The following Service CANNOT be read              : $Service \n";}
	}

	### Log entries for debugging purposes
	Log3 $name, 5, $name. " : km200_ParseHttpResponseInit    : response         : " .$data;
	### Log entries for debugging purposes

	if ($ServiceCounterInit < ($NumberInitServices-1))	### If the list of KM200ALLSERVICES has not been finished yet
	{
		++$ServiceCounterInit;
		$hash->{temp}{ServiceCounterInit}           = $ServiceCounterInit;
		@{$hash->{Secret}{KM200RESPONDINGSERVICES}} = @KM200_RespondingServices;
		@{$hash->{Secret}{KM200WRITEABLESERVICES}}  = @KM200_WriteableServices;
		km200_GetInitService($hash);
	}
	else												### If the list of KM200ALLSERVICES is finished
	{
		$hash->{temp}{ServiceCounterInit} = 0;

		###START###### Filter all static services out of responsive services = responsive dynamic services ########START####
		my @KM200_DynServices = @KM200_RespondingServices;

		foreach my $SearchWord(@{$hash->{Secret}{KM200STATSERVICES}})
		{
			my $FoundPosition = first_index{ $_ eq $SearchWord }@KM200_DynServices;
			if ($FoundPosition >= 0)
			{
				splice(@KM200_DynServices, $FoundPosition, 1);
			}
		}
		####END####### Filter all static services out of responsive services = responsive dynamic services #########END#####

		### Save arrays of services in hash
		@{$hash->{Secret}{KM200RESPONDINGSERVICES}} = @KM200_RespondingServices;
		@{$hash->{Secret}{KM200WRITEABLESERVICES}}  = @KM200_WriteableServices;
		@{$hash->{Secret}{KM200DYNSERVICES}}        = @KM200_DynServices;
		### Save arrays of services in hash

		$hash->{status}{FlagInitRequest}            = false;
	}
	### Clear up temporary variables
	$hash->{temp}{decodedcontent} = "";	
	### Clear up temporary variables
		
	return;
}
####END####### Subroutine to download complete initial data set from gateway ###################################END#####


###START###### Subroutine obtaining dynamic services via HttpUtils ##############################################################START####
sub km200_GetDynService($)
{
	my ($hash, $def)                 = @_;
	my $km200_gateway_host           =   $hash->{URL};
	my $name                         =   $hash->{NAME};
	$hash->{status}{FlagDynRequest}  = true;
	$hash->{STATE}                   = "Polling";
	my @KM200_DynServices            = @{$hash->{Secret}{KM200DYNSERVICES}};
	my $ServiceCounterDyn            =   $hash->{temp}{ServiceCounterDyn};
	my $PollingTimeout               =   $hash->{POLLINGTIMEOUT};
	
	if (@KM200_DynServices != 0)
	{
		my $Service                  =   $KM200_DynServices[$ServiceCounterDyn];
		
		### Console outputs for debugging purposes
		if ($ServiceCounterDyn == 0)
		{
			if ($hash->{CONSOLEMESSAGE} == true) {print("Starting download of dynamic services\n");}
		}
		
		if ($hash->{CONSOLEMESSAGE} == true) {print("$Service\n");}
		### Console outputs for debugging purposes
		
		my $url = "http://" . $km200_gateway_host . $Service;
		my $param = {
						url        => $url,
						timeout    => $PollingTimeout,
						hash       => $hash,
						method     => "GET",
						header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",
						callback   =>  \&km200_ParseHttpResponseDyn
					};

		HttpUtils_NonblockingGet($param);
	}
	else
	{
		Log3 $name, 5, $name . " : No dynamic values available to be read. Skipping download.";
		if ($hash->{CONSOLEMESSAGE} == true) {print("No dynamic values available to be read. Skipping download.\n")}
	}
}
####END####### Subroutine get dynamic data value ###############################################################END#####

###START###### Subroutine to download complete dynamic data set from gateway ##################################START####
# For all responding dynamic services read the respective values from gateway
sub km200_ParseHttpResponseDyn($)
{
    my ($param, $err, $data)    = @_;
    my $hash                    =   $param->{hash};
    my $name                    =   $hash ->{NAME};
	my $ServiceCounterDyn       =   $hash ->{temp}{ServiceCounterDyn};
	my @KM200_DynServices       = @{$hash ->{Secret}{KM200DYNSERVICES}};	
	my $NumberDynServices       = @KM200_DynServices;
	my $Service                 = $KM200_DynServices[$ServiceCounterDyn];
	my $json;	
	
	Log3 $name, 5, $name. " : Parsing response of dynamic service received for: " . $Service;

	if($err ne "")
	{
		Log3 $name, 2, $name . " : ERROR: Service: ".$Service. ": No proper Communication with Gateway: " .$err;
        readingsSingleUpdate($hash, "fullResponse", "ERROR", 1);
		if ($hash->{CONSOLEMESSAGE} == true) {print("km200_ParseHttpResponseDyn ERROR: $err\n");}
	}

	$hash->{temp}{decodedcontent} = $data;
	my $decodedContent = km200_Decrypt($hash);
	
	if ($decodedContent ne "")
	{
		eval 
		{
			$json = decode_json(encode_utf8($decodedContent));
			1;
		}
		or do 
		{
		Log3 $name, 5, $name. " : km200_parseHttpResponseDyn - Data cannot be parsed by JSON on km200 for http://" . $param->{url};
		if ($hash->{CONSOLEMESSAGE} == true) {print("Data not parseable on km200 for " . $param->{url} . "\n");}
		};
		
		if( exists $json -> {"value"})
		{
			my $JsonId         = $json->{id};
			my $JsonType       = $json->{type};
			my $JsonValue      = $json->{value};
			
			### Log entries for debugging purposes
			Log3 $name, 4, $name. " : km200_parseHttpResponseDyn: value found for  : " .$Service;
			Log3 $name, 5, $name. " : km200_parseHttpResponseDyn: id               : " .$JsonId;
			Log3 $name, 5, $name. " : km200_parseHttpResponseDyn: value            : " .$JsonValue;
			### Log entries for debugging purposes
			
			### Write reading
			readingsSingleUpdate( $hash, $JsonId, $JsonValue, 1);
			### Write reading
		}			
		else
		{
			### Log entries for debugging purposes
			Log3 $name, 5, $name. " : km200_parseHttpResponseDyn - value not found for:" .$Service;
			### Log entries for debugging purposes
		}
	}
	else 
	{
		Log3 $name, 5, $name. " : km200_parseHttpResponseDyn - Data not available on km200 for http://" . $param->{url};
		if ($hash->{CONSOLEMESSAGE} == true) {print("Data not available on km200 for " . $param->{url} . "\n");}
	}

	
	### Clear up temporary variables
	$hash->{temp}{decodedcontent} = "";	
	$hash->{temp}{service}        = "";
	### Clear up temporary variables

	if ($ServiceCounterDyn < ($NumberDynServices-1))
	{
		++$ServiceCounterDyn;
		$hash->{temp}{ServiceCounterDyn} = $ServiceCounterDyn;
		km200_GetDynService($hash);
	}
	else
	{
		$hash->{STATE}                   = "Initialized";
		$hash->{temp}{ServiceCounterDyn} = 0;
		if ($hash->{CONSOLEMESSAGE} == true) {print ("Finished\n");}
		###START###### Re-Start the timer #####################################START####
		InternalTimer(gettimeofday()+$hash->{INTERVALDYNVAL}, "km200_GetDynService", $hash, 1);
		####END####### Re-Start the timer ######################################END#####
		
		$hash->{status}{FlagDynRequest}  = false;
	}
	return undef;
}
####END####### Subroutine to download complete dynamic data set from gateway ###################################END#####

###START###### Subroutine obtaining static services via HttpUtils #############################################START####
sub km200_GetStatService($)
{
	my ($hash, $def)                 = @_;
	my $km200_gateway_host           =   $hash->{URL};
	my $name                         =   $hash->{NAME};
	$hash->{status}{FlagStatRequest} = true;
	$hash->{STATE}                   = "Polling";
	my @KM200_StatServices           = @{$hash->{Secret}{KM200STATSERVICES}};
	my $ServiceCounterStat           =   $hash->{temp}{ServiceCounterStat};	
	my $PollingTimeout               =   $hash->{POLLINGTIMEOUT};

	if (@KM200_StatServices != 0)
	{
		my $Service                      =   $KM200_StatServices[$ServiceCounterStat];

		### Console outputs for debugging purposes
		if ($ServiceCounterStat == 0)
		{
			if ($hash->{CONSOLEMESSAGE} == true) {print("Starting download of static  services\n");}
		}
		
		if ($hash->{CONSOLEMESSAGE} == true) {print("$Service\n");}
		### Console outputs for debugging purposes
		
		my $url = "http://" . $km200_gateway_host . $Service;
		my $param = {
						url        => $url,
						timeout    => $PollingTimeout,
						hash       => $hash,
						method     => "GET",
						header     => "agent: TeleHeater/2.2.3\r\nUser-Agent: TeleHeater/2.2.3\r\nAccept: application/json",
						callback   =>  \&km200_ParseHttpResponseStat
					};
		HttpUtils_NonblockingGet($param);
	}
	else
	{
		Log3 $name, 5, $name . " : No static values available to be read. Skipping download.";
		if ($hash->{CONSOLEMESSAGE} == true) {print("No static values available to be read. Skipping download.\n")}
	}
		
}
####END####### Subroutine get static data value ################################################################END#####

###START###### Subroutine to download complete static data set from gateway ###################################START####
# For all responding static services read the respective values from gateway
sub km200_ParseHttpResponseStat($)
{
    my ($param, $err, $data)    = @_;
    my $hash                    =   $param->{hash};
    my $name                    =   $hash ->{NAME};
	my $ServiceCounterStat      =   $hash ->{temp}{ServiceCounterStat};
	my @KM200_StatServices      = @{$hash ->{Secret}{KM200STATSERVICES}};	
	my $NumberStatServices      = @KM200_StatServices;
	my $Service                 = $KM200_StatServices[$ServiceCounterStat];
	my $json;	
	
	Log3 $name, 5, $name. " : Parsing response of static service received for: " . $Service;
	
	if($err ne "")
	{
		Log3 $name, 2, $name . " : ERROR: Service: ".$Service. ": No proper Communication with Gateway: " .$err;
        readingsSingleUpdate($hash, "fullResponse", "ERROR", 1);
		if ($hash->{CONSOLEMESSAGE} == true) {print("km200_ParseHttpResponseStat ERROR: $err\n");}
	}

	$hash->{temp}{decodedcontent} = $data;
	my $decodedContent = km200_Decrypt($hash);
	
	if ($decodedContent ne "")
	{
		eval 
		{
			$json = decode_json(encode_utf8($decodedContent));
			1;
		}
		or do 
		{
		Log3 $name, 5, $name. " : km200_parseHttpResponseStat - Data cannot be parsed by JSON on km200 for http://" . $param->{url};
		if ($hash->{CONSOLEMESSAGE} == true) {print("Data not parseable on km200 for " . $param->{url} . "\n");}
		};

		if( exists $json -> {"value"})
		{
			my $JsonId         = $json->{id};
			my $JsonType       = $json->{type};
			my $JsonValue      = $json->{value};
			
			### Log entries for debugging purposes
			Log3 $name, 4, $name. " : km200_parseHttpResponseStat: value found for  : " .$Service;
			Log3 $name, 5, $name. " : km200_parseHttpResponseStat: id               : " .$JsonId;
			Log3 $name, 5, $name. " : km200_parseHttpResponseStat: value            : " .$JsonValue;
			### Log entries for debugging purposes
			
			### Write reading
			readingsSingleUpdate( $hash, $JsonId, $JsonValue, 1);
			### Write reading
		}			
		else
		{
			### Log entries for debugging purposes
			Log3 $name, 5, $name. " : km200_parseHttpResponseStat - value not found for:" .$Service;
			### Log entries for debugging purposes
		}
	}
	else 
	{
		Log3 $name, 5, $name. " : km200_parseHttpResponseStat - Data not available on km200 for http://" . $param->{url};
	}

	
	### Clear up temporary variables
	$hash->{temp}{decodedcontent} = "";	
	$hash->{temp}{service}        = "";
	### Clear up temporary variables

	if ($ServiceCounterStat < ($NumberStatServices-1))
	{
		++$ServiceCounterStat;
		$hash->{temp}{ServiceCounterStat} = $ServiceCounterStat;
		km200_GetStatService($hash);
	}
	else
	{
		$hash->{STATE}                    = "Initialized";
		$hash->{temp}{ServiceCounterStat} = 0;
		if ($hash->{CONSOLEMESSAGE} == true) {print ("Finished\n");}
		###START###### Re-Start the timer #####################################START####
		InternalTimer(gettimeofday()+$hash->{INTERVALSTATVAL}, "km200_GetStatService", $hash, 1);
		####END####### Re-Start the timer ######################################END#####

		$hash->{status}{FlagStatRequest} = false;
	}
	return undef;
}
####END####### Subroutine to download complete static data set from gateway ####################################END#####

1;

###START###### Description for fhem commandref ################################################################START####
=pod
=begin html

<a name="km200"></a>
<h3>KM200</h3>
<ul>
<table>
	<tr>
		<td>
			The Buderus <a href="http://www.buderus.de/Logamatic_Web_KM200-4608125.html">KM200</a> or <a href="http://de.documents.buderus.com/sitemap/document/id/6720807675">KM50</a> is a communication device to establish a connection between the Buderus central heating control unit and the internet.<BR>
			It has been designed in order to allow the inhabitants accessing their heating system via his Buderus App <a href="http://www.buderus.de/Online_Anwendungen/Apps/fuer_den_Endverbraucher/EasyControl-4848514.html"> EasyControl</a>.<BR>
			Furthermore it allows the maintenance companies to access the central heating control system to read and change settings.<BR>
			The km200 module enables read/write access to these parameters.<BR>
			<BR>
			In order to use the KM200 or KM50 with fhem, you must define the private password with the Buderus App <a href="http://www.buderus.de/Online_Anwendungen/Apps/fuer_den_Endverbraucher/EasyControl-4848514.html"> EasyControl</a> first.<BR>
			<BR>
			<font color="#FF0000"><b><u>Remark:</u></b><BR></font>
			Despite the instruction of the Buderus KM200 Installation guide, the ports 5222 and 5223 should not be opened and allow access to the KM200/KM50 module from outside.<BR>
			You should configure (or leave) your internet router with the respective settings.<BR>
			If you want to read or change settings on the heating system, you should access the central heating control system via your fhem system only.<BR>
			<BR>
			As soon the module has been defined within the fhem.cfg, the module is trying to obtain all known/possible services. <BR>
			After this initial contact, the module differs between a set of continuous (dynamically) changing values (e.g.: temperatures) and not changing static values (e.g.: Firmware version).<BR>
			This two different set of values can be bound to an individual polling interval. Refer to <a href="#KM200Attr">Attributes</a><BR> 
			<BR>
			</td>
	</tr>
</table>
  
<table>
<tr><td><a name="KM200define"></a><b>Define</b></td></tr>
</table>

<table><tr><td><ul><code>define &lt;name&gt; km200 &lt;IPv4-address&gt; &lt;GatewayPassword&gt; &lt;PrivatePassword&gt;</code></ul></td></tr></table>

<ul><ul>
	<table>
		<tr><td align="right" valign="top"><code>&lt;name&gt;</code> : </td><td align="left" valign="top">The name of the device. Recommendation: "myKm200".</td></tr>
		<tr><td align="right" valign="top"><code>&lt;IPv4-address&gt;</code> : </td><td align="left" valign="top">A valid IPv4 address of the KM200 router. You might look into your browser which DHCP address has been given to the KM200/KM50.</td></tr>
		<tr><td align="right" valign="top"><code>&lt;GatewayPassword&gt;</code> : </td><td align="left" valign="top">The gateway password which is provided on the type sign of the KM200/KM50.</td></tr>
		<tr><td align="right" valign="top"><code>&lt;PrivatePassword&gt;</code> : </td><td align="left" valign="top">The private password which has been defined by the user via <a href="http://www.buderus.de/Online_Anwendungen/Apps/fuer_den_Endverbraucher/EasyControl-4848514.html"> EasyControl</a>.</td></tr>
	</table>
</ul></ul>

<BR>

<table>
	<tr><td><a name="KM200Set"></a><b>Set</b></td></tr>
	<tr><td>
		<ul>
				The set function is able to change a value of a service which has the "writeable" - tag within the KM200/KM50 service structure.<BR>
				Most of those values have an additional list of allowed values which are the only ones to be set.<BR>
				Other floatable type values can be changed only within their range of minimum and maximum value.<BR>
		</ul>
	</td></tr>
</table>

<table><tr><td><ul><code>set &lt;service&gt; &lt;value&gt;</code></ul></td></tr></table>

<ul><ul>
	<table>
		<tr><td align="right" valign="top"><code>&lt;service&gt;</code> : </td><td align="left" valign="top">The name of the service which value shall be set. E.g.: "<code>/heatingCircuits/hc1/operationMode</code>"<BR></td></tr>
		<tr><td align="right" valign="top"><code>&lt;value&gt;</code> : </td><td align="left" valign="top">A valid value for this service.<BR></td></tr>
	</table>
</ul></ul>

<BR>

<table>
	<tr><td><a name="KM200Get"></a><b>Get</b></td></tr>
	<tr><td>
		<ul>
				The get function is able to obtain a value of a service within the KM200/KM50 service structure.<BR>
				The additional list of allowed values or their range of minimum and maximum value will not be handed back.<BR>
		</ul>
	</td></tr>
</table>

<table><tr><td><ul><code>get &lt;service&gt;</code></ul></td></tr></table>

<ul><ul>
	<table>
		<tr>
			<td align="right" valign="top"><code>&lt;service&gt;</code> : </td><td align="left" valign="top">The name of the service which value shall be obtained. E.g.: "<code>/heatingCircuits/hc1/operationMode</code>"<BR>
																											&nbsp;&nbsp;It returns only the value but not the unit or the range or list of allowed values possible.<BR>
																			</td>
													
		</tr>
	</table>
</ul></ul>

<BR>

<table>
	<tr><td><a name="KM200Attr"></a><b>Attributes</b></td></tr>
	<tr><td>
		<ul>
				The following user attributes can be used with the km200 module in addition to the global ones e.g. <a href="#room">room</a>.<BR>
		</ul>
	</td></tr>
</table>

<ul><ul>
	<table>
		<tr>
			<td>
			<tr><td align="right" valign="top"><li><code>IntervalDynVal</code> : </li></td><td align="left" valign="top">A valid polling interval for the dynamically changing values of the KM200/KM50. The value must be >=20s to allow the km200 module to perform a full polling procedure. <BR>
																												   The default value is 90s.<BR>
			</td></tr>
			
			</td>
		</tr>
	</table>
</ul></ul>
	
<ul><ul>
	<table>
		<tr>
			<td>
			<tr><td align="right" valign="top"><li><code>IntervalStatVal</code> : </li></td><td align="left" valign="top">A valid polling interval for the statical values of the KM200/KM50. The value must be >=20s to allow the km200 module to perform a full polling procedure. <BR>
																												   The default value is 3600s.<BR>
																												   The value of "0" will disable the polling of statical values until the next fhem restart or a reload of the fhem.cfg - file.<BR>
			</td></tr>
			
			</td>
		</tr>
	</table>
</ul></ul>

<ul><ul>
	<table>
		<tr>
			<td>
			<tr><td align="right" valign="top"><li><code>PollingTimeout</code> : </li></td><td align="left" valign="top">A valid time in order to allow the module to wait for a response of the KM200/KM50. Usually this value does not need to be changed but might in case of slow network or slow response.<BR>
																												   The default and minimum value is 5s.<BR>
			</td></tr>
			
			</td>
		</tr>
	</table>
</ul></ul>

<ul><ul>
	<table>
		<tr>
			<td>
			<tr><td align="right" valign="top"><li><code>ConsoleMessage</code> : </li></td><td align="left" valign="top">A valid boolean value whether the activity and error messages shall be displayed in the console window. "0" (deactivated) or "1" (activated)<BR>
																												   The default value 0 (deactivated).<BR>
			</td></tr>			
			</td>
		</tr>
	</table>
</ul></ul></ul>