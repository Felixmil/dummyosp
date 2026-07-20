# the Aciclovir example simulation loads

    Code
      ospsuite::simulationResultsToTibble(res[[1]])
    Output
      # A tibble: 982 x 9
         IndividualId  Time paths    simulationValues TimeDimension TimeUnit dimension
                <int> <dbl> <chr>               <dbl> <chr>         <chr>    <chr>    
       1            0     0 Organis~             0    Time          min      Concentr~
       2            0     0 Organis~             0    Time          min      Concentr~
       3            0     1 Organis~             3.25 Time          min      Concentr~
       4            0     1 Organis~            32.6  Time          min      Concentr~
       5            0     2 Organis~             9.10 Time          min      Concentr~
       6            0     2 Organis~            38.9  Time          min      Concentr~
       7            0     3 Organis~            15.0  Time          min      Concentr~
       8            0     3 Organis~            43.9  Time          min      Concentr~
       9            0     4 Organis~            20.7  Time          min      Concentr~
      10            0     4 Organis~            48.5  Time          min      Concentr~
      # i 972 more rows
      # i 2 more variables: unit <chr>, molWeight <dbl>

