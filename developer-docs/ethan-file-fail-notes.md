OMI / WinRM gem connection Failure 

Commands to test with:

```
Commands to test over Bolt Linux WinRM

./windows.ps1 -names '\Processor(_Total)\% Processor Time'

bolt script run .\foo\tasks\windows.ps1 '\Processor(_Total)\% Processor Time' --nodes winrm://localhost -u Administrator -p Qu@lity! --no-ssl


bolt task show foo::windows --modulepath .

$names = @('\Processor(_Total)\% Processor Time', '\memory\% committed bytes in use')
$counters = @{"names" = $names}

Get-Counter $names


bolt task run foo::windows --modulepath .  --nodes winrm://localhost -u Administrator -p Qu@lity! --no-ssl --params '{"names": ["\\Processor(_Total)\\% Processor Time", "\\memory\\% commited bytes in use" ]}'


bolt task run foo::windows --modulepath .  --nodes winrm://localhost -u Administrator -p Qu@lity! --no-ssl --params ($counters | ConvertTo-Json -Compress)



vi /cygdrive/C/Program\ Files/Puppet\ Labs/Bolt/share/PowerShell/Modules/PuppetBolt/PuppetBolt.psm1
```




Occurs in 

```
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45367 Priority=DEBUG (E)Handle:(0x555a2cd8c050), ClientAuthState = 4, EngineAuthState = 4
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45006 Priority=DEBUG AgentElem: Posting message for interaction [0x555a2cdbf438]<-0x555a2cd8c0c0
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45008 Priority=DEBUG _AgentElem_FindRequest, Agent 0x555a2cdbf3a0(0x555a2cdbf400), Found key: 98, Request: 0x555a2cd8bf60(0x555a2cd8bf70)
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45038 Priority=DEBUG _RequestItem_ParentPost: 0x555a2cd8bf60, msg: 0x555a2cd94e78
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45217 Priority=DEBUG WsmanConnection: Posting msg(0x555a2cd94e78:4:PostResultMsg:10021c) on interaction 0x555a2cd82c68<-[0x555a2cdb22b0]<-0x555a2cd8bfa8
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45219 Priority=DEBUG WsmanConnection: Close on interaction [0x555a2cdb22b0]<-0x555a2cd8bfa8 outstandingRequest: 1, single_message: 0x555a2cd93ef8
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45034 Priority=DEBUG HttpSocket: Posting message for interaction [0x555a2cd82c68]<-0x555a2cdb22e8
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45206 Priority=DEBUG Sending msg(0x555a2cdd1178:19:HttpResponseMsg:0) on own thread
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45010 Priority=DEBUG RequestItem: Ack on interaction [0x555a2cd8bfa8]<-0x555a2cdb2320
2018/12/20 00:23:18 [6064,6064] DEBUG: null(0): EventId=45151 Priority=DEBUG ProtocolSocket: Ack on interaction [0x555a2cd8c0c0]<-0x555a2cdbf438
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45037 Priority=DEBUG HttpSocket: 0x555a2cd82c30 _HttpSocket_Aux_NewRequest, Request: 0x555a2cdc9228
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45231 Priority=DEBUG RETURN{wsmanparser.c:339}
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45231 Priority=DEBUG RETURN{wsmanparser.c:413}
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45231 Priority=DEBUG RETURN{wsmanparser.c:1396}
2018/12/20 00:23:29 [6064,6064] WARNING: null(0): EventId=30137 Priority=WARNING wsman: failed to parse WS header
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45034 Priority=DEBUG HttpSocket: Posting message for interaction [0x555a2cd82c68]<-0x555a2cdb22e8
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45206 Priority=DEBUG Sending msg(0x555a2cda8a28:19:HttpResponseMsg:0) on own thread
2018/12/20 00:23:29 [6064,6064] DEBUG: null(0): EventId=45035 Priority=DEBUG HttpSocket: Ack on interaction [0x555a2cd82c68]<-0x555a2cdb22e8
```

Request:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:a="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:b="http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd" xmlns:cfg="http://schemas.microsoft.com/wbem/wsman/1/config" xmlns:n="http://schemas.xmlsoap.org/ws/2004/09/enumeration" xmlns:p="http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd" xmlns:rsp="http://schemas.microsoft.com/wbem/wsman/1/windows/shell" xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:w="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd" xmlns:x="http://schemas.xmlsoap.org/ws/2004/09/transfer" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <s:Header>
    <a:To>https://g6ejqe5ek63kdn4.delivery.puppetlabs.net:5986/wsman</a:To>
    <a:ReplyTo>
      <a:Address mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</a:Address>
    </a:ReplyTo>
    <w:MaxEnvelopeSize mustUnderstand="true">153600</w:MaxEnvelopeSize>
    <a:MessageID>uuid:00BE60B9-7C9B-42EC-9849-EC6357E56778</a:MessageID>
    <p:SessionId mustUnderstand="false">uuid:9480624A-1E81-4A24-8368-FE2D95914CDB</p:SessionId>
    <w:Locale mustUnderstand="false" xml:lang="en-US"/>
    <p:DataLocale mustUnderstand="false" xml:lang="en-US"/>
    <w:OperationTimeout>PT60S</w:OperationTimeout>
    <w:ResourceURI mustUnderstand="true">http://schemas.microsoft.com/powershell/Microsoft.PowerShell</w:ResourceURI>
    <a:Action mustUnderstand="true">http://schemas.xmlsoap.org/ws/2004/09/transfer/Delete</a:Action>
    <w:SelectorSet>
      <w:Selector Name="ShellId">0A97EC20-2CCA-40A3-AD35-35FAEE6385DA</w:Selector>
    </w:SelectorSet>
  </s:Header>
  <s:Body/>
</s:Envelope>
```

Response:

```xml
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://www.w3.org/2003/05/soap-envelope" xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:e="http://schemas.xmlsoap.org/ws/2004/08/eventing" xmlns:msftwinrm="http://schemas.microsoft.com/wbem/wsman/1/wsman.xsd" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsen="http://schemas.xmlsoap.org/ws/2004/09/enumeration" xmlns:wsman="http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd" xmlns:wsmb="http://schemas.dmtf.org/wbem/wsman/1/cimbinding.xsd" xmlns:wsmid="http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd" xmlns:wxf="http://schemas.xmlsoap.org/ws/2004/09/transfer" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SOAP-ENV:Header>
    <wsa:To>http://schemas.xmlsoap.org/ws/2004/08/addressing/role/anonymous</wsa:To>
    <wsa:Action>http://schemas.dmtf.org/wbem/wsman/1/wsman/fault</wsa:Action>
    <wsa:MessageID>uuid:5BD58AA0-7D56-0005-0000-000000770000</wsa:MessageID>
    <wsa:RelatesTo>uuid:00BE60B9-7C9B-42EC-9849-EC6357E56778</wsa:RelatesTo>
  </SOAP-ENV:Header>
  <SOAP-ENV:Body>
    <SOAP-ENV:Fault>
      <SOAP-ENV:Code>
        <SOAP-ENV:Value>SOAP-ENV:Receiver</SOAP-ENV:Value>
        <SOAP-ENV:Subcode>
          <SOAP-ENV:Value>wsman:InternalError</SOAP-ENV:Value>
        </SOAP-ENV:Subcode>
      </SOAP-ENV:Code>
      <SOAP-ENV:Reason>
        <SOAP-ENV:Text xml:lang="en-US"/>
      </SOAP-ENV:Reason>
    </SOAP-ENV:Fault>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
```


