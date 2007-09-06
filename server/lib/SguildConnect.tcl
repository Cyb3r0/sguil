# $Id: SguildConnect.tcl,v 1.20 2007/09/06 19:17:14 bamm Exp $

#
# ClientConnect: Sets up comms for client/server
#
proc ClientConnect { socketID IPAddr port } {
  global socketInfo VERSION

  LogMessage "Client Connect: $IPAddr $port $socketID"
  
  # Check the client access list
  if { ![ValidateClientAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "Valid client access: $IPAddr"
  set socketInfo($socketID) [list $IPAddr $port]
  fconfigure $socketID -buffering line
  fileevent $socketID readable [list ClientCmdRcvd $socketID]
  # Send version info
  if [catch {SendSocket $socketID "$VERSION"} sendError ] {
    return
  }
  # Give the user 90 seconds to send login info
  after 90000 CheckLoginStatus $socketID $IPAddr $port

}

proc ClientVersionCheck { socketID clientVersion } {

  global socketInfo VERSION
  global OPENSSL KEY PEM

  if { $clientVersion != $VERSION } {
    catch {close $socketID} tmpError
    LogMessage "ERROR: Client connect denied - mismatched versions"
    LogMessage "CLIENT VERSION: $clientVersion"
    LogMessage "SERVER VERSION: $VERSION"
    close $socketID
    ClientExitClose $socketID
    return
  }

  if {$OPENSSL} {
    #tls::import $socketID -server true -keyfile $KEY -certfile $PEM
    if { [catch {tls::import $socketID -server true -keyfile $KEY -certfile $PEM} importError] } {
        LogMessage "ERROR: $importError"
        close $socketID
        ClientExitClose $socketID
    }

    if { [catch {tls::handshake $socketID} results] } {
        LogMessage "ERROR: $results"
        close $socketID
        ClientExitClose socketID
    } else {
        puts "DEBUG #### results for $socketID ==> $results"
    }

  }

}

proc SensorConnect { socketID IPAddr port } {

  global VERSION AGENT_OPENSSL AGENT_VERSION KEY PEM

  LogMessage "Sensor agent connect from $IPAddr:$port $socketID"

  # Check the sensor access list
  if { ![ValidateSensorAccess $IPAddr] } {
    SendSocket $socketID "Connection Refused."
    catch {close $socketID} tmpError
    LogMessage "Invalid access attempt from $IPAddr"
    return
  }
  LogMessage "Valid sensor agent: $IPAddr"
  fconfigure $socketID -buffering line
  fileevent $socketID readable [list SensorCmdRcvd $socketID]
  # Version check
  if [catch {puts $socketID $AGENT_VERSION} tmpError] {
    LogMessage "ERROR: $tmpError"
    catch {close $socketID}
    return
  }
}

proc AgentVersionCheck { socketID agentVersion } {

  global VERSION AGENT_OPENSSL AGENT_VERSION KEY PEM

  if { $agentVersion != $AGENT_VERSION } {
    catch {close $socketID} 
    LogMessage "ERROR: Agent connect denied - mismatched versions"
    LogMessage "AGENT VERSION: $agentVersion"
    LogMessage "SERVER VERSION: $VERSION"
    return
  }

  if {$AGENT_OPENSSL} {
    if { [catch {tls::import $socketID -server true -keyfile $KEY -certfile $PEM} importError] } {
        LogMessage "ERROR: $importError"
        catch {close $socketID}
        CleanUpDisconnectedAgent $socketID
        return
    }

    if { [catch {tls::handshake $socketID} results] } {
        LogMessage "ERROR: $results"
        close $socketID
        ClientExitClose socketID
    } 

  } 

}

proc AgentInit { socketID sensorName byStatus } {

    global agentSocketArray agentSensorNameArray
    global socketInfo

    set sensorID [GetSensorID $sensorName]

    set agentSocketArray($sensorName) $socketID
    set agentSensorNameArray($socketID) $sensorName
    set agentSocketSid($socketID) $sensorID

    SendSensorAgent $socketID [list BarnyardSensorID $sensorID]
    SendSystemInfoMsg $sensorName "Agent connected."
    SendAllSensorStatusInfo

}

proc CleanUpDisconnectedAgent { socketID } {

    global agentSocketArray agentSensorNameArray validSensorSockets
    global agentStatusList agentSocketInfo

    # Remove the agent socket from the valid (registered) list. 
    if [info exists validSensorSockets] {
        set validSensorSockets [ldelete $validSensorSockets $socketID]
    }

    if { [array exists agentSocketInfo] && [info exists agentSocketInfo($socketID)] } {
  
        set sid [lindex $agentSocketInfo($socketID) 0]
        if { [array exists agentStatusList] && [info exists agentStatusList($sid)] } {

            set agentStatusList($sid) [lreplace $agentStatusList($sid) 4 4 0 ]

        } 

        unset agentSocketInfo($socketID)

    }

    SendAllSensorStatusInfo

}

proc HandShake { socketID cmd } {
  if {[eof $socketID]} {
    close $socketID
    ClientExitClose socketID
  } elseif { [catch {tls::handshake $socketID} results] } {
    LogMessage "ERROR: $results"
    close $socketID
    ClientExitClose socketID
  } elseif {$results == 1} {
    InfoMessage "Handshake complete for $socketID"
    fileevent $socketID readable [list $cmd $socketID]
  }
}


proc CheckLoginStatus { socketID IPAddr port } {

    global socketInfo

    if { [array exists socketInfo] && [info exists socketInfo($socketID)] } {
 
        # Check to make sure the socket is being used by the same dst ip and port
        if { [lindex $socketInfo($socketID) 0] == "$IPAddr" && [lindex $socketInfo($socketID) 1] == "$port" } {

            # Finally see if there is a username associated
            if { [llength $socketInfo($socketID)] < 3 } {

                LogMessage "Removing stale client: $socketInfo($socketID)"
                # Looks like the socket is stale.
                catch {close $socketID}
                ClientExitClose $socketID

            }

        }

    }

}
