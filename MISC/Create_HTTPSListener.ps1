# Step 1: Generate a self-signed certificate for HTTPS
$certThumbprint = (New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My").Thumbprint

# Step 2: Bind the certificate to the listener port (8443)
$port = 8443
$listenerAddress = "https://+:$port/"

# Add HTTPS binding
netsh http add sslcert ipport=0.0.0.0:$port certhash=$certThumbprint appid='{00112233-4455-6677-8899-AABBCCDDEEFF}'

# Step 3: Start the HTTPS listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($listenerAddress)
$listener.Start()
Write-Output "HTTPS listener started on $listenerAddress"

# Step 4: Continuously listen for incoming requests
while ($listener.IsListening) {
    # Asynchronously get the context of an incoming request
    $context = $listener.GetContext()

    # Step 5: Read and parse the request body
    $request = $context.Request
    $reader = New-Object IO.StreamReader($request.InputStream)
    $body = $reader.ReadToEnd()

    # Step 6: Attempt to extract "deviceName" from JSON body
    $jsonData = $body | ConvertFrom-Json
    $deviceName = $jsonData.deviceName

    if ($deviceName) {
        # Step 7: Use the device name in a local script or action
        Write-Output "Device name received: $deviceName"

        # Example: Save the device name to a text file
        $filePath = "C:\Scripts\DeviceName.txt"
        Set-Content -Path $filePath -Value $deviceName
        Write-Output "Device name saved to $filePath"

        # Or you can call another script with $deviceName as an argument
        # & "C:\Scripts\OtherScript.ps1" -DeviceName $deviceName
    } else {
        Write-Output "No device name found in the request."
    }

    # Respond back to the client
    $response = $context.Response
    $response.StatusCode = 200
    $response.StatusDescription = "OK"
    $response.Close()
}

# Step 8: Stop listener when done (Control + C in PowerShell to interrupt)
$listener.Stop()
Write-Output "HTTPS listener stopped."
