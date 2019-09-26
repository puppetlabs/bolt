-- START-FACT
fact :: Int -> Int
fact 0 = 1
fact n = n * fact (n-1)
-- END-FACT
main = print $ fact 7
