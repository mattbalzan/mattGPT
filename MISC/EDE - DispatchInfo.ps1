# --[ EDE - Dispatch Info ]
# --[ Matt Balzan | mattGPT.co.uk | 12/03/2025 ]

<#

    Description:    1. Downloads real-time UK GOV bank holidays JSON data.
                    2. Filters for upcoming public holidays.
                    3. Displays end date when total hours are met.
                    4. Displays Hours used per month.
                    5. Displays a list of working days.
                    6. Highlights all the Bank holidays if they run on working days.

    Usage:          StartDate   | 02/06/2025
                    HoursPerDay | 8
                    TotalHours  | 500
                    WorkingDays | Monday,Friday

    Version:        12-03-2025 | Version 1.0 | Original

#>

# --[ Customise Inputs ]
$StartDate = "02/06/2025"  # Start date (UK format)
$HoursPerDay = 8    # Hours per working day
$TotalHours = 500   # Total working hours
$WorkingDays = @("Monday", "Friday")  # eg. Work only on Mondays & Fridays


# --[ Get GOV.UK Bank Holidays (England, Wales, Scotland, Northern Ireland) ]
function Get-UKBankHolidays {
    $url = "https://www.gov.uk/bank-holidays.json"
    $today = Get-Date  # Get current date

    try {
        $holidaysData = Invoke-RestMethod -Uri $url
        $holidays = @{
            England = @{};
            Scotland = @{};
            NI = @{};
        }

        # Extract holidays and store them as [date] -> "Holiday Name"
        foreach ($event in $holidaysData.'england-and-wales'.events) {
            if ([DateTime]$event.date -ge $today) {
                $holidays.England[[DateTime]$event.date] = $event.title
            }
        }
        foreach ($event in $holidaysData.scotland.events) {
            if ([DateTime]$event.date -ge $today) {
                $holidays.Scotland[[DateTime]$event.date] = $event.title
            }
        }
        foreach ($event in $holidaysData.'northern-ireland'.events) {
            if ([DateTime]$event.date -ge $today) {
                $holidays.NI[[DateTime]$event.date] = $event.title
            }
        }

        return $holidays
    } catch {

        #Write-Host $_.Exception.Message
        Write-Host "Failed to fetch UK bank holidays. Continuing without them."
        return @{ England = @{}; Scotland = @{}; NI = @{} }
    }
}


# --[ Convert Start Date to DateTime Object ]
$StartDate = [DateTime]::ParseExact($StartDate, "dd/MM/yyyy", $null)

# --[ Get Future UK Bank Holidays ]
$bankHolidays = Get-UKBankHolidays

# --[ Initialize Variables ]
$remainingHours = $TotalHours
$currentDate = $StartDate
$monthlyHours = @{}  # Store hours used per month
$datesUsed = @()      # Store all working dates

# --[ Calculate Working Dates ]
while ($remainingHours -gt 0) {
    # Check if it's a valid working day (not weekend & within selected workdays)
    if ($workingDays -contains $currentDate.DayOfWeek.ToString()) {
        $datesUsed += $currentDate
        $monthKey = $currentDate.ToString("yyyy-MM")

        # Track hours per month
        if ($monthlyHours.ContainsKey($monthKey)) {
            $monthlyHours[$monthKey] += $HoursPerDay
        } else {
            $monthlyHours[$monthKey] = $HoursPerDay
        }

        # Deduct from remaining hours
        $remainingHours -= $HoursPerDay
    }
    
    # Move to next day
    $currentDate = $currentDate.AddDays(1)
}

cls
# --[ Output ASCII Table ]
Write-Host "   EDE WORKING HOURS BREAKDOWN   " -f Black -b White
Write-Host "      developed by mattGPT       " -f Black -b White

# --[ Monthly Hours Table ]
Write-Host "`nHours Used Per Month:" -f White -b Black
Write-Host "+-------------+--------------+"
Write-Host "|  Month      |  Hours Used  |"
Write-Host "+-------------+--------------+"
foreach ($month in $monthlyHours.Keys | Sort-Object) {
    $line = "| {0,-11} | {1,12} |" -f $month, $monthlyHours[$month]
    Write-Host $line
}
Write-Host "+-------------+--------------+"

# --[ Dates Table ]--
Write-Host "`nList of Working Dates:" -f White -b Black
Write-Host "+---------------+------------+---------------------------------------+"
Write-Host "| Date          | Day        | UK Public/Bank Holiday                |"
Write-Host "+---------------+------------+---------------------------------------+"

foreach ($date in $datesUsed) {
    $formattedDate = $date.ToString("dd/MM/yyyy")
    $dayOfWeek = $date.DayOfWeek.ToString()
    $line = "| {0,-13} | {1,-10} |" -f $formattedDate, $dayOfWeek
    $note = ""

    # Check if date is a public holiday and get its name
    if ($bankHolidays.England.ContainsKey($date)) {
        $note = $bankHolidays.England[$date]
        Write-Host "$line $note | England - Wales" -ForegroundColor Green
    }
    elseif ($bankHolidays.Scotland.ContainsKey($date)) {
        $note = $bankHolidays.Scotland[$date]
        Write-Host "$line $note | Scotland" -ForegroundColor Cyan
    }
    elseif ($bankHolidays.NI.ContainsKey($date)) {
        $note = $bankHolidays.NI[$date]
        Write-Host "$line $note | Northern Ireland" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "$line"
    }
}

Write-Host "+---------------+------------+---------------------------------------+"
                                      
# --[ Display End Date ]
$endDateFormatted = $datesUsed[-1].ToString("dd/MM/yyyy")
Write-Host "`nTotal $TotalHours hours will be completed on: " -NoNewline
Write-Host $endDateFormatted -f Black -b Yellow
Write-Host "======================================================================"

# --[ End of script ]
