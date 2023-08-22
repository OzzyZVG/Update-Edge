$computers = Get-Content "\\BR01S-FS\Resources\Scripts\Edge\computer_list.txt"
$latestEdgeVersion = "115.0.1901.203"
$EdgeInstallerUrl = "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/e1ce42f8-6dd5-48ca-a8e4-7f8efd660e57/MicrosoftEdgeEnterpriseX64.msi"
$LocalInstallerPath = "C:\Temp\MicrosoftEdgeEnterpriseX64.msi"
$logPath = "c:\temp\EdgeUpdateLog.txt"

$credentials = Get-Credential -Message "Insira as credenciais de administrador"

foreach ($computer in $computers) {
    Write-Output "Verificando se a máquina $computer está online"
    if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
        Write-Output "Máquina online, acessando via hostname"
        $pssession = New-PSSession -ComputerName $computer -Credential $credentials -ErrorAction SilentlyContinue
        if (!$pssession) {
            Write-Output "Falha ao acessar a máquina $computer"
            continue
        }
        Write-Output "Conexão estabelecida. Verificando a versão do Edge..."
        $edgeVersion = Invoke-Command -Session $pssession -ScriptBlock {
            (Get-Command "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe").FileVersionInfo.ProductVersion
        }
        if ($edgeVersion -ne $latestEdgeVersion) {
            Write-Output "Versão desatualizada do Edge. Iniciando a atualização..."
            Invoke-Command -Session $pssession -ScriptBlock {
                if (!(Test-Path -Path $using:LocalInstallerPath)) {
                    Write-Output "Baixando o instalador do Edge na máquina $using:computer"
                    Invoke-WebRequest -Uri $using:EdgeInstallerUrl -OutFile $using:LocalInstallerPath
                }
                Write-Output "Instalando o Edge na máquina $using:computer"
                Start-Process "msiexec" -ArgumentList "/i $using:LocalInstallerPath /qn /l*v `"$using:LocalInstallerPath.log`"" -Wait -PassThru
            }
            Write-Output "Edge instalado com sucesso na máquina $computer"
            Add-Content -Path $logPath -Value $computer
            $computers = $computers | Where-Object { $_ -ne $computer }
            Set-Content -Path "C:\Temp\computer_list2.txt" -Value $computers
        } else {
            Write-Output "Edge já está na versão mais recente na máquina $computer"
            Add-Content -Path $logPath -Value $computer
            $computers = $computers | Where-Object { $_ -ne $computer }
            Set-Content -Path "C:\Temp\computer_list2.txt" -Value $computers
        }
        # Execute o comando remoto a partir da raiz do executável usando Invoke-Command dentro da sessão remota
        Write-Output "Executando o comando no host $computer ..."
        Invoke-Command -Session $pssession -ScriptBlock {
            Set-Location "C:\Program Files\tenable\nessus agent"
            & ".\nessuscli.exe" scan-triggers --start --uuid=091d168d-0109-45a3-8ae9-845a8aaa4f47
        }
        Remove-PSSession $pssession
    } else {
        Write-Output "Máquina $computer está offline"
    }
}