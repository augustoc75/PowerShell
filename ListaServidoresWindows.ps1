# Este script PowerShell lista todos os servidores Windows em um domínio Active Directory, 
# recuperando o atributo LastLogonTimestamp para cada servidor e exibindo os resultados em uma
# tabela formatada ordenada pelo atributo LastLogonTimeStamp em ordem decrescente.
Import-Module ActiveDirectory

# Query para obter uma lista de todos os servidores Windows no domínio
$servidores = Get-ADComputer -Filter {OperatingSystem -Like "*Windows Server*"} -Property Name, OperatingSystem, LastLogonTimestamp
# Cria uma lista para armazenar os resultados
$resultados = @()
foreach ($servidor in $servidores) {
    # Converte LastLogonTimestamp para uma data legível
    $lastLogon = if ($servidor.LastLogonTimestamp) {
        [DateTime]::FromFileTime($servidor.LastLogonTimestamp)
    } else {
        "Nunca"
    }

    # Adiciona o resultado à lista
    $resultados += [PSCustomObject]@{
        NomeServidor     = $servidor.Name
        Sisoperacional   = $servidor.OperatingSystem
        LastLogonTimeStamp = $lastLogon
    }
}
# Ordena os resultados pelo LastLogonTimeStamp em ordem decrescente
$resultadosOrdenados = $resultados | Sort-Object -Property LastLogonTimeStamp -Descending
# Exibe os resultados em uma tabela formatada
$resultadosOrdenados | Format-Table -AutoSize

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


