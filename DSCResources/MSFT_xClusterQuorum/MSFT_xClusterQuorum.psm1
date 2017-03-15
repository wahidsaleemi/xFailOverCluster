
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String] $IsSingleInstance,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NodeMajority', 'NodeAndDiskMajority', 'NodeAndFileShareMajority', 'DiskOnly', 'CloudWitness')]
        [String] $Type,
        
        [Parameter(Mandatory = $false)]
        [String] $Resource,
                
        [Parameter(Mandatory = $false)]
        [String] $ResourceKey						 
    )

    $ClusterQuorum = Get-ClusterQuorum

    switch ($ClusterQuorum.QuorumType)
    {
        # WS2016 only
        'Majority' {
            if ($ClusterQuorum.QuorumResource -eq $null)
            {
                $ClusterQuorumType = 'NodeMajority'
            }
            elseif ($ClusterQuorum.QuorumResource.ResourceType.DisplayName -eq 'Physical Disk')
            {
                $ClusterQuorumType = 'NodeAndDiskMajority'
            }
            elseif ($ClusterQuorum.QuorumResource.ResourceType.DisplayName -eq 'File Share Witness')
            {
                $ClusterQuorumType = 'NodeAndFileShareMajority'
            }
            elseif ($ClusterQuorum.QuorumResource.ResourceType.DisplayName -eq 'Cloud Witness')
            {
                $ClusterQuorumType = 'CloudWitness'
            }																							   		 
            else
            {
                throw "Unknown quorum resource: $($ClusterQuorum.QuorumResource)"
            }
        }

        # WS2012R2 only
        'NodeMajority' {
            $ClusterQuorumType = 'NodeMajority'
        }
        'NodeAndDiskMajority' {
            $ClusterQuorumType = 'NodeAndDiskMajority'
        }
        'NodeAndFileShareMajority' {
            $ClusterQuorumType = 'NodeAndFileShareMajority'
        }

        # All
        'DiskOnly' {
            $ClusterQuorumType = 'DiskOnly'
        }

        # Default
        default {
            throw "Unknown quorum type: $($ClusterQuorum.QuorumType)"
        }
    }

    if ($ClusterQuorumType -eq 'NodeAndFileShareMajority')
    {
        $ClusterQuorumResource = $ClusterQuorum.QuorumResource | Get-ClusterParameter -Name SharePath | Select-Object -ExpandProperty Value
    }
    elseif ($ClusterQuorumType -eq 'CloudWitness')
    {
        $ClusterQuorumResource = $ClusterQuorum.QuorumResource | Get-ClusterParameter -Name AccountName | Select-Object -ExpandProperty Value
    }
    else
    {
        $ClusterQuorumResource = [String] $ClusterQuorum.QuorumResource.Name
    }

    @{
        IsSingleInstance = $IsSingleInstance
        Type             = $ClusterQuorumType
        Resource         = $ClusterQuorumResource
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String] $IsSingleInstance,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NodeMajority', 'NodeAndDiskMajority', 'NodeAndFileShareMajority', 'DiskOnly', 'CloudWitness')]
        [String] $Type,
        
        [Parameter(Mandatory = $false)]
        [String] $Resource,

        [Parameter(Mandatory = $false)]
        [String] $ResourceKey
    )

    switch ($Type)
    {
        'NodeMajority' {
            Set-ClusterQuorum -NoWitness
        }

        'NodeAndDiskMajority' {
            Set-ClusterQuorum -DiskWitness $Resource
        }

        'NodeAndFileShareMajority' {
            Set-ClusterQuorum -FileShareWitness $Resource
        }

        'DiskOnly' {
            Set-ClusterQuorum -DiskOnly $Resource
        }

        'CloudWitness' {
            Set-ClusterQuorum -CloudWitness -AccountName $Resource -AccessKey $ResourceKey -Endpoint 'core.windows.net'
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes')]
        [String] $IsSingleInstance,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NodeMajority', 'NodeAndDiskMajority', 'NodeAndFileShareMajority', 'DiskOnly')]
        [String] $Type,
        
        [Parameter(Mandatory = $false)]
        [String] $Resource,
                
        [Parameter(Mandatory = $false)]
        [String] $ResourceKey 
    )
    
    $CurrentQuorum = Get-TargetResource -IsSingleInstance $IsSingleInstance
    
    return (
        ($CurrentQuorum.Type -eq $Type) -and
        ($CurrentQuorum.Resource -eq $Resource)
    )
}

Export-ModuleMember -Function *-TargetResource
