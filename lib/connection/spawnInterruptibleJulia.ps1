param(
	[Int32] $port, 
	[string] $jlpath, 
	[string] $jloptions
)

# start Julia
$proc = Start-Process $jlpath "$jloptions -e `"import Atom; @sync Atom.connect($port)`"" -NoNewWindow -PassThru

# import GenerateConsoleCtrlEvent:
$MethodDefinition = @'
[DllImport("Kernel32.dll", CharSet = CharSet.Unicode)]
public static extern bool GenerateConsoleCtrlEvent(uint dwCtrlEvent, uint dwProcessGroupId);
'@

$Kernel32 = Add-Type -MemberDefinition $MethodDefinition -Name 'Kernel32' -Namespace 'Win32' -PassThru

function Receive-TCPMessage {
    param ( [ValidateNotNullOrEmpty()]
        [int] $Port
    )
    try {
        $endpoint = new-object System.Net.IPEndPoint([ipaddress]::any, $port)
        $listener = new-object System.Net.Sockets.TcpListener $endpoint
        $listener.start()

        $data = $listener.AcceptTcpClient() # will block here until connection
        $bytes = New-Object System.Byte[] 6
        $stream = $data.GetStream()

        while (($i = $stream.Read($bytes,0,$bytes.Length)) -ne 0){
            $EncodedText = New-Object System.Text.ASCIIEncoding
            $data = $EncodedText.GetString($bytes,0, $i)
            Write-Output $data
        }

        $stream.close()
        $listener.stop()
    }
	catch [exception]{
        echo "julia-client: Internal Error:"
        echo "$exception"
    }
}

# the port should probably be determined dynamically (by nodejs):
while ($true){
	$msg = Receive-TCPMessage -Port 26992 # wait for interrupts
	if ($msg -match "SIGINT"){
		$status = $Kernel32::GenerateConsoleCtrlEvent(0, $proc.Id)
		# this is necessary for GenerateConsoleCtrlEvent to actually do something:
		echo "Interrupting Julia..."
		if (!$status) {
			echo "julia-client: Internal Error: Interrupting Julia failed."
		}
	}
	if ($msg -match "KILL"){
		$proc.Kill()
		Exit
	}
}
