
updateOracle () {
    for assetPair in "${assetPairs[@]}"; do
        local _quorum
        local _prices
        local _median
        local entries=()
        local _sortedEntries=()

# todo check if we want to have quorum function in the contract itself
        #get quorum for asset pair
#        _quorum=$(pullOracleQuorum "$assetPair")
#        if [[ -z "$_quorum" || "$_quorum" -le 0 ]]; then
#          error "Error - Invalid quorum, skipping..."
#          continue
#        fi
        _quorum=1

        pullLatestPricesOfAssetPair "$assetPair" "$_quorum"

        for entry in "${entries[@]}"; do
            verbose --raw "Price entry" "$(jq -c 'tojson' <<<"$entry")"
        done

        [ "$(isQuorum "$assetPair" "${#entries[@]}")" == "false" ] && continue
        _prices=$(extractPrices "${entries[@]}")

# todo remove this and enable median price after dev
        local allPrices=()
        local allTimes=()
        local allR=()
        local allS=()
        local allV=()
        sortMsgs "${entries[@]}"
        verbose --raw "sorted messages" "${_sortedEntries[*]}"
        generateCalldata "${_sortedEntries[@]}"
        pushOraclePrice "$assetPair" || error "pushOraclePrice failed" "asset=$assetPair"

#        _median=$(getMedian "${_prices[@]}")
#        verbose "median" "val=$_median"

        if [[ ( "$(isPriceValid "$_median")" == "true" ) \
        && ( "$(isOracleStale "$assetPair" "$_median")" == "true" \
        || "$(isOracleExpired "$assetPair")" == "true" ) ]]; then
            local allPrices=()
            local allTimes=()
            local allR=()
            local allS=()
            local allV=()
            sortMsgs "${entries[@]}"
            verbose --raw "sorted messages" "${_sortedEntries[*]}"
            generateCalldata "${_sortedEntries[@]}"
            pushOraclePrice "$assetPair" || error "pushOraclePrice failed" "asset=$assetPair"
        fi
    done
}

#pulls latest price of an asset from each feed
pullLatestPricesOfAssetPair () {
    local _assetPair="$1"
    _assetPair="${_assetPair^^}"
    local _quorum="$2"
    local _randomizedFeeds=()

    #randomize order of feeds
    _randomizedFeeds=( $(shuf -e "${feeds[@]}") )

    log "Pulling $_assetPair Messages"
    #only query age param from contract once per pull
    local _oracleAge=$(pullOracleTime "$_assetPair")
    #scrape all feeds
    for feed in "${_randomizedFeeds[@]}"; do
        #stop collecting messages once quorum has been achieved
        if [ "${#entries[@]}" -eq "$_quorum" ]; then
          log "Collected enough messages for quorum"
          break
        fi
 
        log "Polling feed" "feedAddr=$feed"
        # Grab latest price msg of asset from feed then verify price msg is
        # valid and not expired.
        local priceEntry
        if priceEntry=$(transportPull "$feed" "$_assetPair") \
        && [ -n "$priceEntry" ]
        then
            log "Adding message catalogue" "feedAddr=$feed"
            log "Adding message catalogue" "entry=$priceEntry"
            entries+=( "$priceEntry" )
        fi
    done
}

sortMsgs () {
    local _msgs=( "$@" )
    verbose --raw "Presorted Messages" "${_msgs[*]}"
    readarray -t _sortedEntries < <(echo "${_msgs[*]}" | jq -s '.' | jq 'sort_by(.price)' | jq -c '.[]')
}

generateCalldata () {
    local _msgs=( "$@" )
    local _sig

    verbose "Generating Calldata..."
    for msg in "${_msgs[@]}"; do
        _sig=$( echo "$msg" | jq -r '.signature' )

        allR+=( "${_sig:0:64}" )
        allS+=( "${_sig:64:64}" )
        allV+=( "$(ethereum --to-dec "${_sig:128:2}")" )
        allPrices+=( "$(ethereum --to-dec "$( echo "$msg" | jq -r '.priceHex' )")" )
        allTimes+=( "$(ethereum --to-dec "$( echo "$msg" | jq -r '.timeHex' )")" )
        allSignatures+=( "${_sig}" )
    done

    verbose "allPrices=${allPrices[*]}" "allTimes=${allTimes[*]}" "allR=${allR[*]}" "allS=${allS[*]}" "allV=${allV[*]}" "allSignatures=${allSignatures[*]}"
}
