# Este script PowerShell lista todos os servidores Windows em um domínio Active Directory, 
# recuperando o atributo LastLogonTimestamp para cada servidor e exibindo os resultados em uma
# tabela formatada ordenada pelo atributo LastLogonTimeStamp em ordem decrescente.
Import-Module ActiveDirectory

# Query para obter uma lista de todos os servidores Windows no domínio
$servidores = Get-ADComputer -Filter {OperatingSystem -Like "*Windows Server*"} -Property Name, OperatingSystem, LastLogonTimestamp
# Cria uma lista para armazenar os resultados
$resultados = @()
# Threshold para determinar se tentamos obter IP (últimos 14 dias)
$recentThreshold = (Get-Date).AddDays(-14)
foreach ($servidor in $servidores) {
    # Converte LastLogonTimestamp para uma data legível
    $lastLogon = if ($servidor.LastLogonTimestamp) {
        [DateTime]::FromFileTime($servidor.LastLogonTimestamp)
    } else {
        $null
    }

    # Determina IP somente se last logon for inferior a 14 dias (mais recente que $recentThreshold)
    $ip = $null
    if ($lastLogon -is [DateTime] -and $lastLogon -gt $recentThreshold) {
        try {
            $ping = Test-Connection -ComputerName $servidor.Name -Count 1 -ErrorAction Stop
            $ip = $ping.Address.IPAddressToString
        } catch {
            # fallback para Resolve-DnsName (A/AAAA)
            try {
                $dns = Resolve-DnsName -Name $servidor.Name -ErrorAction Stop
                $ip = ($dns | Where-Object { $_.Type -in 'A','AAAA' } | Select-Object -First 1 -ExpandProperty IPAddress) -join ','
            } catch {
                $ip = $null
            }
        }
    }

    # Adiciona o resultado à lista (inclui IP, ou 'N/D' se não disponível)
    $resultados += [PSCustomObject]@{
        NomeServidor        = $servidor.Name
        Sisoperacional      = $servidor.OperatingSystem
        LastLogonTimeStamp  = if ($lastLogon) { $lastLogon } else { 'Nunca' }
        IP                  = if ($ip) { $ip } else { 'N/D' }
    }
}
# Ordena os resultados pelo LastLogonTimeStamp em ordem decrescente
$resultadosOrdenados = $resultados | Sort-Object -Property LastLogonTimeStamp -Descending
# Exibe os resultados em uma tabela formatada
$resultadosOrdenados | Format-Table -AutoSize
# Grava os resultados em um arquivo CSV
$resultadosOrdenados | Export-Csv -Path "ServidoresWindows_com_IP.csv" -NoTypeInformation -Encoding UTF8

# Agrupa os servidores por sistema operacional e conta quantos servidores existem para cada sistema
$contagemSO = $servidores |
    Group-Object -Property OperatingSystem |
    Select-Object @{Name='SistemaOperacional';Expression={$_.Name}}, @{Name='QuantidadeServidores';Expression={$_.Count}} |
    Sort-Object -Property QuantidadeServidores -Descending
# Exibe a contagem por sistema operacional
Write-Host "`nContagem de servidores por sistema operacional:" -ForegroundColor Cyan
$contagemSO | Format-Table 

# Exibe a contagem total de servidores encontrados
Write-Host "`nTotal de servidores encontrados: $($resultadosOrdenados.Count)"

# Conta servidores com LastLogonTimeStamp com mais de 60 dias
$threshold = (Get-Date).AddDays(-60)
$servidoresMaisDe60Dias = ($resultados | Where-Object { $_.LastLogonTimeStamp -is [DateTime] -and $_.LastLogonTimeStamp -lt $threshold }).Count
Write-Host "`nServidores com LastLogonTimeStamp com mais de 60 dias: $servidoresMaisDe60Dias" -ForegroundColor Yellow


