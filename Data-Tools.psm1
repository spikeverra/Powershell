#Warning: Run-Sqlite has hardcoded path!

function Convert-Csv-To-Xls{

    Param(
        [switch]$reverse,
        
        [Parameter(Mandatory=$true)][string]$path,
        [string]$xlsTable,
        [string]$delimiter,
        [string]$password        
    )
    try{

        if (!(Test-Path $path)){ Write-Output $path + "Does not exist. Input a real path" ; throw}
        $extn = [IO.Path]::GetExtension($path)
         
        $worksheets = @()

        $obj = New-Object -ComObject Excel.Application    
        $obj.Visible       = $false
        $obj.DisplayAlerts = $false
    
         if($reverse){
            
            if ($extn -notin (".xlsx",".xlsb") ){echo "Input file is not an excel file" ; throw}
        
            $workbook = $obj.Workbooks.Open($path,0,0,5,$password)
            
            $workbook.Worksheets| % {
            
                if($_.Name -eq $xlsTable) {
            
                    $worksheet = $workbook.worksheets.item(1)

                    $xlsTable = $xlsTable -replace " ",""  
                   
                    $new_path = ($path -replace $extn, ("_{0}.{1}" -f $xlsTable,"csv"))
                   
                    $_.SaveAs($new_path ,6) # Comma delimited
                    $obj.Quit()
					
					#Private function to this module
					
                    Convert-Comma-To-Pipe-Delimited -path $new_path

                    return
                }  
            }
        }

        else{
            if ($extn -ne ".csv" ){echo "Input file is not a csv file" ; throw}   
        
            #if($delimiter -ne "|"){ echo "Delimiter must be a pipe |" ; throw}

            $workbook = $obj.Workbooks.Add(1)
            $worksheet = $workbook.worksheets.Item(1)

            if($xlsTable -ne $null){ $worksheet.name = $xlsTable}

            #QueryTables = "Data » From Text" in Excel
            $Connector = $worksheet.QueryTables.add(("TEXT;" + $path),$worksheet.Range("A1"))
            $query = $worksheet.QueryTables.item($Connector.name)


            $query.TextFileOtherDelimiter = $delimiter #"|"
            # $Excel.Application.International(5)


            # Set the format to delimited and text for every column
            ## Create an array of 2s is used with the preceding comma
            $query.TextFileParseType  = 1
            $query.TextFileColumnDataTypes = ,2 * $worksheet.Cells.Columns.Count
            $query.AdjustColumnWidth = 1


            $query.Refresh() ;$query.Delete()


            $Workbook.SaveAs(($path -replace ".csv" ,".xlsx"),51)
        
            $workbook.Save()
            $workbook.Close()
            $obj.Quit()
        }

        
    }
    catch
    {
        $obj.Quit()
        throw
    }
    return
}   
function Convert-Comma-To-Pipe-Delimited{
   
    Param( [Parameter(Mandatory=$true)][string]$path, 
           [switch]  $skipHeaderExport 
    )
    
    if (!(Test-Path $path)){ Write-Output $path + "Does not exist. Input a real path" ; throw}
    
    
    $data = Import-Csv -Path $path -Delimiter "," 
    
    if( $data -eq $null ){ echo "File is empty"; return }
    
    $data | Export-Csv -Path $path -Delimiter "|" -NoTypeInformation 
       
       
    ( Get-Content $path ) -replace '"',"" | Set-Content $path
    
    if( $skipHeaderExport ) { ( Get-Content $path | Select-Object -Skip 1 ) | Set-Content $path }
    
    return
}
function Convert-Accdb-To-Csv {
    Param(
        [Parameter(Mandatory=$true)][string]$csvPath,
        [Parameter(Mandatory=$true)][object]$object,
        [Parameter(Mandatory=$true)][string]$query,
        [switch] $skipHeaderExport
        )       
    
    $bool = $false

    
    if( $skipHeaderExport ){ $bool = $true }

    $extn = [IO.Path]::GetExtension($csvPath)
    
    if ($extn -ne ".csv" ){echo "Input file is not a csv file" ; throw}
     
        
    $object.DoCmd.Transfertext( 2, [Type]::Missing, $query, $csvPath, $True)
    
    if (!(Test-Path $csvPath)){ Write-Output $csvPath + "Data did not export from Accdb" ; throw}
    
    #Inherited Fx
    Convert-Comma-To-Pipe-Delimited -path $csvPath -skipHeaderExport $bool
    
    return
}
function Export-PSObj-To-Piped-Csv {

    Param(
        [Parameter(Mandatory=$true)][object]$array,
        [Parameter(Mandatory=$true)][string]$path, 
        [Parameter(Mandatory=$true)][string]$file
    )

    $csvExt    = 'csv'
    $delimiter = "|"
    
    $path      = "{0}\{1}.{2}" -f $path, $file, $csvExt
    
    if( Test-Path $path ){ Remove-item -Path $path }  
    
    $array | ConvertTo-Csv -NoTypeInformation -Delimiter $delimiter  | Out-File -Append $path
        
    (Get-Content $path ) -replace '"',"" | Set-Content $path
    
    return 
}
function Get-Xls-Tabs{
 
   Param(
      [Parameter(Mandatory=$true)][string]$path
     ,[string]$password
   )

    $tabs = @()
    $obj = new-object -comobject excel.application  
    $obj.Visible = $True 
 
    
    if($password -ne $null) {
        $workbook = $obj.Workbooks.Open($path,0,0,5,$password)
    }
    else  {
        $workbook = $obj.Workbooks.Open($path)
    }

    if($workbook -eq $null)  {
        Write-Host "No Excel Tabs Found"
        return    
    }
    else  {
        foreach ($worksheet in $workbook.Worksheets) { 
             $tabs += $worksheet.Name
        } 
    }
        
    $obj.Quit()

   return $tabs
}
function Run-Sqlite{

    Param(
          [Parameter(Mandatory=$true)][string]$db_path,
          [string]$query_path,
          [string]$query_file,
          [AllowNull()][string]$sql
        )  

    if ([IO.Path]::GetExtension($db_path) -ne ".db"  ){ echo "Database file is not a .db file" ; throw}  

    $db_path = $db_path -replace '\\', '/'

    if([string]::IsNullOrEmpty($sql)) {
        $query_path = ("{0}\{1}" -f $query_path,$query_file ) -replace '\\', '/'

        if( !(Test-Path $query_path) ) { echo "Invalid input, no code or file is found" ; throw }

        elseif ([IO.Path]::GetExtension($query_path) -ne ".sql" ){ echo "Query file is not a .sql file"   ; throw} 

        else{ $sql = (Get-Content -path $query_path) -join "`n" }
    }
   
    $sql | C:\binary\SQLite3\sqlite3.exe $db_path
   
    $sql = $null

    return
}


#Merge with Convert-Csv-To-Xls Fx
function Convert-Csv-To-Xls_Ext1 {
     Param(
        [Parameter(Mandatory=$true)][string]$xlsPath,
        [Parameter(Mandatory=$true)][string]$csvPath,
        [Parameter(Mandatory=$true)][string]$xlsTable,
        [Parameter(Mandatory=$true)][string]$xlsRange,
        [Parameter(Mandatory=$true)][string]$delimiter
        ) 
    if ($delimiter -notin ('|',",")) {Write-Output "Bad delimiter input" ;return} 
       
    $obj = New-Object -ComObject Excel.Application 
         
    $obj.Visible       = $false
    $obj.DisplayAlerts = $false

    $workbook = $obj.Workbooks.Open($xlsPath)
        
    $worksheetCount = 1  
              
    $workbook.Worksheets| % {
                
        if( $_.Name -eq $xlsTable ) { $worksheet = $workbook.worksheets.item( $worksheetCount ) } 
         
        else{ $worksheetCount += 1 }
    }
            
    $Connector = $worksheet.QueryTables.add(  ( "TEXT;" + $csvPath ) ,$worksheet.Range( $xlsRange )  )

    $xlsQuery  = $worksheet.QueryTables.item( $Connector.name )
    
    #LOC: Make sure to match delimiter
    $xlsQuery.TextFileOtherDelimiter = $delimiter ; $xlsQuery.Refresh() ; $xlsQuery.Delete()

    $workbook.Save() ; $workbook.Close()
        
    $obj.Quit()

    return
}
Function RenameTab ($xlsPath, $oldName, $newName)
{
    $xldoc =  New-Object -ComObject "Excel.Application"
    $xldoc.Visible = $false
    $xldoc.DisplayAlerts = $false

    $workbook = $xldoc.Workbooks.Open($xlsPath)
    foreach ($worksheet in $workbook.Worksheets) {
        if ($worksheet.name -eq $oldName) {
            $worksheet = $workbook.worksheets.item(1)
            $worksheet.name = $newName
            $workbook.SaveAs($xlsPath)
            $workbook.Save()
            $workbook.Close()
        }
    }

    $xldoc.Quit()
}

