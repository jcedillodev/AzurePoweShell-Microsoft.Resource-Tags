function CsvExtractionTags {
    param (
        [string[]]$FilePath,
        [string[]]$TagsAction
        )

    # Read exported CSV file content
    $csvContent = Import-Csv -Path $FilePath;

    # Check for an existing Azure PowerShell context/session, if none, then login
    $azctx = Get-AzContext -ErrorAction Break

    # Variable to check # of updates from .csv file
    $i = 0

    # Iterate through the CSV file content
    foreach($line in $csvContent){

        # Setup collection of resource properties to use a filter from the CSV columns
        $azResProps = @("Location", "Name", "ResourceGroup", "ResourceId", "Type", "Updated")
        $tags = @{}

        # Iterate through the CSV line object's properties to filter out resources properties above
        $tagColumns = $line.PSObject.Properties | ForEach-Object {
            if($_.Name -notin $azResProps){
                # Extract csv line column names/values
                $tagName = $_.Name
                $tagValue = $_.Value

                # Check for empty string tag/column values and disallow their inclusion with tags obj
                if($tagValue.Length -gt 0){
                    $tags.Add($tagName, $tagValue)
                }
            }
        }
        # DEBUG: Call/display tags object
        $tags

        if(($line.ResourceId).Length -gt 0){
            # Extract subscription ID for current CVS line resource ID column
            $subscriptionId = (($line.ResourceId).split('/'))[2]

            # If there is no existing session in Azure PowerShell, connect into Azure
            if(!$azctx){
                # Log into Azure
                Connect-AzAccount -ErrorAction Break
            }

            # Check if the current lines 'Updated' column value is set to FALSE, if so then proceed with update
            if($line.Updated -eq "FALSE"){
                # Increment by 1 when updating tags from the .csv file
                $i++

                # Set current session context to the extracted subscription ID
                Set-AzContext -Subscription $subscriptionId -ErrorAction Break

                # Update tagging by using the operation set passed operation value (Merge/Replace/Delete)
                Update-AzTag -ResourceId $line.ResourceId -Tag $tags -Operation $TagsAction -ErrorAction Break

                # After updating resource tags, set the current lines 'Updated' column value to TRUE confirm this line has been updated
                $line.Updated = "TRUE"

                # Get/format datetime
                $csvModDt = Get-Date
                $formattedCvsModDt = $csvModDt.ToString("yyyy-MM-dd_HHmm")

                # Setup modified filename path to create new/modified .csv file
                $filename = ($FilePath.split("\"))[($FilePath.split("\").Length - 1)]
                $modifiedfile = "$(($filename.split(".")[0]))-$($formattedCvsModDt)"

                # Export modified .csv file
                $csvContent | Export-Csv -Path "$env:userprofile\Downloads\$modifiedfile.csv" -NoTypeInformation
            }
        }
    }
    Write-Host "Number of changes from .csv file: $($i)"
}