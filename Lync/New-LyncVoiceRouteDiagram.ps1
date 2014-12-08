<#
.SYNOPSIS
Create Graphviz diagram definition file for one or more Lync 2013 voice policies.
.DESCRIPTION
Create Graphviz diagram definition file for one or more Lync 2013 voice policies.
.PARAMETER PolicyFilter
Specify a policy name filter.
.PARAMETER OutputFile
Specifies the name of the file to output the definition information to. Default is Lync-Diagram.txt 

.EXAMPLE
PS > New-LyncVoiceRouteDiagram

Description
-----------
Creates a new Graphviz definition file containing all lync voice policies.

.NOTES
Author: Zachary Loeber
Site: http://www.the-little-things.net/
Requires: Powershell 2.0, Lync
Version History
1.0.0 - 12/01/2014
- Initial release

.LINK
https://github.com/zloeber/Powershell/blob/master/Lync/New-LyncVoiceRouteDiagram.ps1
.LINK
http://www.the-little-things.net
#>
[CmdLetBinding()]
param(
    [Parameter(Position=0, HelpMessage="Enter a policy")]
    [string]$PolicyFilter = '*',
    [Parameter(Position=1, HelpMessage="File to export Graphviz definition file to.")]
    [string]$OutputFile = 'Lync-Diagram.txt'
)

#region Requirements
function Split-ByLength{
    <#
    .SYNOPSIS
    Splits string up by Split length.

    .DESCRIPTION
    Convert a string with a varying length of characters to an array formatted to a specific number of characters per item.

    .EXAMPLE
    Split-ByLength '012345678901234567890123456789123' -Split 10

    0123456789
    0123456789
    0123456789
    123

    .LINK
    http://stackoverflow.com/questions/17171531/powershell-string-to-array/17173367#17173367
    #>

    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string[]]$InputObject,

        [int]$Split=10
    )
    begin{}
    process{
        foreach($string in $InputObject){
            $len = $string.Length

            $repeat=[Math]::Floor($len/$Split)

            for($i=0;$i-lt$repeat;$i++){
                #Write-Output ($string[($i*$Split)..($i*$Split+$Split-1)])
                Write-Output $string.Substring($i*$Split,$Split)
            }
            if($remainder=$len%$split){
                #Write-Output ($string[($len-$remainder)..($len-1)])
                Write-Output $string.Substring($len-$remainder)
            }
        }        
    }
    end{}
}

# The overall output template
$GraphvizTemplate = @'
digraph LyncVoicePolicies { 
    node [shape=text];
    graph [nodesep=5, ranksep=5, overlap=false, rankdir=LR];
    edge[weight=0.2];
    
@@VoicePolicies@@

@@VoiceRoutes@@

@@Trunks@@

@@VoicePolicyToVoiceRoutes@@

@@VoiceRoutesToTrunks@@
}

'@

#Newline
$nl = [Environment]::NewLine

## Map hashes used in several locations later on
# Voice Route Map
$VoiceRouteMap = @{}
$Count = 0
(Get-CsVoiceRoute).Identity | Foreach {
    $VoiceRouteMap."$($_)" = "VoiceRoute_$Count"
    $Count++
}

# PSTN Usage Map
$PstnUsageMap = @{}
$Count = 0
$PstnUsageLabels = ''
(Get-CsPstnUsage).Usage | Foreach {
    $PstnUsageMap."$($_)" = "PstnUsage_$Count"
    $Count++
}

# Trunk Map
$TrunkMap = @{}
$Count = 0
(Get-CsTrunk).PoolFqdn | Foreach {
    $TrunkMap."$($_)" = "Trunk_$Count"
    $Count++
}

# Policy Map
$PolicyMap = @{}
$Count = 0
(Get-CsVoicePolicy).Identity | Foreach {
    $PolicyName = $_ -replace 'tag:',''
    $PolicyMap."$($PolicyName)" = "Policy_$Count"
    $Count++
}
#endregion

#region Policies


$VoicePolicies = Get-CSVoicePolicy -Filter $PolicyFilter | Select @{n='Name';e={$_.Identity -replace 'tag:',''}}, `
                                            @{n='Scope';e={switch ($_.ScopeClass) {
                                                            'Tag' {'User'}
                                                            'Global' {'Global'}
                                                            'Site' {'Site'}}}}, `
                                            PstnUsages

$GraphvizVoicePolicyTemplate = @'
    policies [label=<<table BORDER="0" CELLBORDER="1" CELLSPACING="0">
                        <tr>
                            <td COLSPAN="3" BGCOLOR="gray">Voice Policies</td>
                        </tr>
                        <tr>
                            <td BGCOLOR="gray">Name</td>
                            <td BGCOLOR="gray">Scope</td>
                            <td BGCOLOR="gray">PSTN Usages</td>
                        </tr>
@@0@@
                   </table>>];
'@
$VoicePolicyTableRowTemplate = @'

                        <tr>
                            <td rowspan="@@rowspan@@">@@0@@</td>
                            <td rowspan="@@rowspan@@">@@1@@</td>
                            <td PORT="@@2@@">@@3@@</td>
                        </tr>

'@

$PolicyTablePSTNRowTemplate = @'

                        <tr>
                            <td PORT="@@0@@">@@1@@</td>
                        </tr>
'@

$VoicePolicyRows = ''
$VoicePolicyPstnUsages = @()
$UniqueVPPstnUsageAssignments = @()
ForEach ($Policy in $VoicePolicies)
{
    $VoicePolicyPSTNRows = ''
    $rowspan = ($Policy.PSTNUsages).Count
    if ($rowspan -gt 0)
    {
        $tempPolicyTableRowTemplate = $VoicePolicyTableRowTemplate -replace '@@rowspan@@',$rowspan
        for ($index = 0; $index -lt $rowspan; $index++) {
            $tmpPstnUsage = ($Policy.PSTNUsages)[$index]
            $UniqueVPPstnUsageAssignments += $tmpPstnUsage
            $tmpPolicyMap = $PolicyMap."$($Policy.Name)"
            $tmpPstnMap = $PstnUsageMap."$tmpPstnUsage"
            $VoicePolicyPstnUsage = "$tmpPolicyMap-$tmpPstnMap"
            $VoicePolicyPstnUsages += $VoicePolicyPstnUsage
        	if ($index -eq 0)
            {
                $tempPolicyTableRowTemplate = $tempPolicyTableRowTemplate -replace '@@2@@',"$VoicePolicyPstnUsage"
                $tempPolicyTableRowTemplate = $tempPolicyTableRowTemplate -replace '@@3@@',"$tmpPstnUsage"
            }
            else
            {
                $tmp = $PolicyTablePSTNRowTemplate -replace '@@0@@',"$VoicePolicyPstnUsage"
                $VoicePolicyPSTNRows += $tmp -replace '@@1@@',"$tmpPstnUsage"
            }
        }
    }
    $VoicePolicyRows += $tempPolicyTableRowTemplate -replace '@@0@@',$Policy.Name `
                                                    -replace '@@1@@',$Policy.Scope
    $VoicePolicyRows += $VoicePolicyPSTNRows
}

if ($VoicePolicyRows -ne '')
{
    $GraphvizVoicePolicyTemplate = $GraphvizVoicePolicyTemplate -replace '@@0@@',$VoicePolicyRows
}
else
{
    $GraphvizVoicePolicyTemplate = ''
}

$UniqueVPPstnUsageAssignments = $UniqueVPPstnUsageAssignments | Select -Unique
#endregion

#region Voice Route
$GraphvizRouteTemplate = @'
    route [label=<<table BORDER="0" CELLBORDER="1" CELLSPACING="0">
                  <tr>
                    <td colspan="6" BGCOLOR="gray">Voice Routes</td>
                  </tr>
                  <tr>
                    <td BGCOLOR="gray">PSTN Usage</td>
                    <td BGCOLOR="gray">Order</td>
                    <td BGCOLOR="gray">Name</td>
                    <td BGCOLOR="gray">Match Patterns</td>
                    <td BGCOLOR="gray">Surpress Caller ID</td>
                    <td BGCOLOR="gray">PSTN Gateway</td>
                  </tr>
@@0@@
                </table>>];
'@

$RouteTableRowTemplate = @'
                  <tr>
                    <td PORT="@@0@@">@@1@@</td>
                    <td rowspan="@@rowspan@@">@@2@@</td>
                    <td rowspan="@@rowspan@@">@@3@@</td>
                    <td rowspan="@@rowspan@@">@@4@@</td>
                    <td rowspan="@@rowspan@@">@@5@@</td>
                    <td rowspan="@@rowspan@@" PORT="@@RouteGatewayPort@@">@@6@@</td>
                  </tr>

'@

$RouteTablePSTNRowTemplate = @'
                  <tr>
                    <td PORT="@@0@@">@@1@@</td>
                  </tr>

'@

[regex] $UsedPSTNs = '(?i)^(' + (($UniqueVPPstnUsageAssignments |foreach {[regex]::escape($_)}) –join "|") + ')$'

$VoiceRoutes = Get-CSVoiceRoute | 
                Where {(@($_.PstnUsages) -match $UsedPSTNs).count -gt 0} | 
                Select PSTNUsages,Priority,Identity,NumberPattern,SuppressCallerID,PSTNGatewayList

$VoiceRouteRows = ''
$RoutePstnUsages = @()
$RouteGatewayCount = 0
$VoiceRoutesToTrunks = ''
ForEach ($Route in $VoiceRoutes)
{
    $VoiceRoutePSTNRows = ''
    $rowspan = ($Route.PSTNUsages).Count
    $tempRouteTableRowTemplate = $RouteTableRowTemplate -replace '@@rowspan@@',$rowspan
    $tempRouteTableRowTemplate = $tempRouteTableRowTemplate -replace '@@RouteGatewayPort@@',"RouteGateway_$RouteGatewayCount"
    for ($index = 0; $index -lt $rowspan; $index++) {
        $tmpPstnUsage = ($Route.PSTNUsages)[$index]
        $tmpRouteMap = $VoiceRouteMap."$($Route.Identity)"
        $tmpPstnMap = $PstnUsageMap."$tmpPstnUsage"
        $RoutePstnUsage = "$tmpRouteMap-$tmpPstnMap"
        $RoutePstnUsages += $RoutePstnUsage
    	if ($index -eq 0)
        {
            $tempRouteTableRowTemplate = $tempRouteTableRowTemplate -replace '@@0@@',"$RoutePstnUsage"
            $tempRouteTableRowTemplate = $tempRouteTableRowTemplate -replace '@@1@@',"$tmpPstnUsage"
        }
        else
        {
            $tmp = $RouteTablePSTNRowTemplate -replace '@@0@@',"$RoutePstnUsage"
            $VoiceRoutePSTNRows += $tmp -replace '@@1@@',"$tmpPstnUsage"
        }
    }
    $VoiceRouteRows += $tempRouteTableRowTemplate -replace '@@2@@',$Route.Priority `
                                          -replace '@@3@@',$Route.Identity `
                                          -replace '@@4@@',$(@($Route.NumberPattern | Split-ByLength -Split 30) -join '<br/>') `
                                          -replace '@@5@@',$Route.SuppressCallerID `
                                          -replace '@@6@@',$(($Route.PSTNGatewayList -join '<br/>') -replace 'PstnGateway:','')
    $VoiceRouteRows += $VoiceRoutePSTNRows
    $Route.PSTNGatewayList | Foreach {
        $tmp = $_ -replace 'PstnGateway:',''
        $trunk = $TrunkMap."$($tmp)"
        $VoiceRoutesToTrunks += "    route:`"RouteGateway_$RouteGatewayCount`" -> trunks:`"$($trunk)`"$nl"
    }
    $RouteGatewayCount++
}

$GraphvizRouteTemplate = $GraphvizRouteTemplate -replace '@@0@@',$VoiceRouteRows
#endregion

#region Trunk Stuff
$GraphvizTrunkTemplate = @'
    trunks [label=<<table BORDER="0" CELLBORDER="1" CELLSPACING="0">
                      <tr>
                        <td COLSPAN="6" BGCOLOR="gray">Trunks</td>
                      </tr>
                      <tr>
                        <td BGCOLOR="gray">Name</td>
                        <td BGCOLOR="gray">Site</td>
                        <td BGCOLOR="gray">Calling Number Rules</td>
                        <td BGCOLOR="gray">Called Number Rules</td>
                        <td BGCOLOR="gray">Tcp Port</td>
                        <td BGCOLOR="gray">Tls Port</td>
                      </tr>
@@0@@
                   </table>>];

'@

$TrunkTableRowTemplate = @'
                      <tr>
                        <td PORT="@@0@@">@@1@@</td>
                        <td>@@2@@</td>
                        <td>@@3@@</td>
                        <td>@@4@@</td>
                        <td>@@5@@</td>
                        <td>@@6@@</td>
                      </tr>
                      
'@

$Trunks = Get-CsTrunk | select @{n='Name';e={$_.PoolFqdn}}, `
                               @{n='Site';e={$_.SiteID -replace 'Site:',''}}, `
                               @{n='CallingRules';e={$_.CallingNumberRules -Join '<br/>'}}, `
                               @{n='CalledRules';e={$_.CalledNumberRules -Join '<br/>'}}, `
                               GatewaySipClientTcpPort, `
                               GatewaySipClientTlsPort

$TrunkTableRows = ''
$Trunks | foreach {
    $TrunkTableRows += $TrunkTableRowTemplate -replace '@@0@@',$TrunkMap."$($_.Name)" `
                                              -replace '@@1@@',$_.Name `
                                              -replace '@@2@@',$_.Site `
                                              -replace '@@3@@',$_.CallingRules `
                                              -replace '@@4@@',$_.CalledRules `
                                              -replace '@@5@@',$_.GatewaySipClientTcpPort `
                                              -replace '@@6@@',$_.GatewaySipClientTlsPort
}

if ($TrunkTableRows -ne '')
{
    $GraphvizTrunkTemplate = $GraphvizTrunkTemplate -replace '@@0@@',$TrunkTableRows
}
else
{
    $GraphvizTrunkTemplate = ''
}
#endregion

#region policy to voice route edges 
$VoicePolicyPSTNtoRoutePSTNEdges = ''
ForEach ($VoicePolicyPstnUsage in $VoicePolicyPstnUsages)
{
    $RoutePstnUsages | Where {$(($_ -split '-')[1]) -eq $(($VoicePolicyPstnUsage -split '-')[1])} | ForEach {
        $VoicePolicyPSTNtoRoutePSTNEdges += "    policies:`"$($VoicePolicyPstnUsage)`" -> route:`"$($_)`"$nl"
    }
}
#endregion

#region Create Final Graphviz Definition
$Output = $GraphvizTemplate -replace '@@VoicePolicies@@',$GraphvizVoicePolicyTemplate `
                            -replace '@@VoiceRoutes@@',$GraphvizRouteTemplate `
                            -replace '@@Trunks@@',$GraphvizTrunkTemplate `
                            -replace '@@VoicePolicyToVoiceRoutes@@',$VoicePolicyPSTNtoRoutePSTNEdges `
                            -replace '@@VoiceRoutesToTrunks@@',$VoiceRoutesToTrunks

#endregion

$Output | Out-File -Encoding ASCII $OutputFile
Write-Output "$OutputFile has been generated. Please feed this file into Graphviz to create a diagram"