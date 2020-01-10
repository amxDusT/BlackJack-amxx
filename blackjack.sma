#include < amxmodx >
#include < amxmisc >

// choose for what mod. 
// edit line 25-26-27 for custom mod.

#define JAILBREAK       // jailbreak by natsheh
//#define CSTRIKE
//#define ZOMBIE

#define BACK_CARD   "zback"
#define DIR_CARDS "http://info.ugc-gaming.net/motd/cs/Cards"

#if defined CSTRIKE
    #include < cstrike >
    #define set_user_cash   cs_set_user_money 
    #define get_user_cash   cs_get_user_money
#elseif defined JAILBREAK   
    #include < jailbreak_core >
    #define set_user_cash   jb_set_user_cash
    #define get_user_cash   jb_get_user_cash
#elseif defined ZOMBIE
    #include < zombieplague >
    #define set_user_cash   zp_set_user_ammo_packs
    #define get_user_cash   zp_get_user_ammo_packs
    #define CASH_SYMBOL     "Ammo "
#else 
    #include < cstrike >
    #define set_user_cash   cs_set_user_money /*add here function to set user type of cash*/    
    #define get_user_cash   cs_get_user_money /*add here function to get user type of cash*/
#endif

#if !defined CASH_SYMBOL
    #define CASH_SYMBOL "$" 
#endif

//max player cases possible = 11 cards
#define MAX_PLAYER_CARDS    11
//max PC game cases = 10 cards
#define MAX_PC_CARDS        10
#define MAX_UNIT            10000
#define MIN_UNIT            100


new const VERSION[] = "1.4";

#define set_bit(%1,%2)      (%1 |= (1<<(%2&31)))
#define clear_bit(%1,%2)    (%1 &= ~(1<<(%2&31)))
#define check_bit(%1,%2)    (%1 & (1<<(%2&31)))

#if AMXX_VERSION_NUM < 183
    #define MAX_PLAYERS     32
    #include <cromchat>
    #define client_disconnected     client_disconnect
#endif

new gCards[ MAX_PLAYERS + 1 ][ MAX_PLAYER_CARDS ]

new gPc[ MAX_PLAYERS + 1 ][ MAX_PC_CARDS ]

enum
{
    PLAYER = 0, 
    NPC
}
enum
{
    DOWN = 0,
    RAISE
}
enum
{
    CARD2 = 2,
    CARD3,
    CARD4,
    CARD5,
    CARD6,
    CARD7,
    CARD8,
    CARD9,
    CARD10,
    CARDJ,
    CARDQ,
    CARDK,
    CARDA
}


// Clubs, Diamons, Hearts, Spades
new const g_Cards[][] = { 
    "",     "",     "",     "",              //easier to get values with these spaces
    "2C",   "2D",   "2H",   "2S",
    "3C",   "3D",   "3H",   "3S",
    "4C",   "4D",   "4H",   "4S",
    "5C",   "5D",   "5H",   "5S",
    "6C",   "6D",   "6H",   "6S",
    "7C",   "7D",   "7H",   "7S",
    "8C",   "8D",   "8H",   "8S",
    "9C",   "9D",   "9H",   "9S",
    "10C",  "10D",  "10H",  "10S",
    "JC",   "JD",   "JH",   "JS",
    "QC",   "QD",   "QH",   "QS",
    "KC",   "KD",   "KH",   "KS",
    "AC",   "AD",   "AH",   "AS"
}

new gCash[ 33 ] //saved won / lost cash
// won last game?, show dealer's card?, hasplayed at least once?, isPlaying?, draw? 
new bLast, bShow, bFinished, bStarted, bDraw

new const disableItem = (1<<26) 

new p_cash_ads
new p_only_dead
new p_allow_spec
new p_min_bet
public plugin_init(){
    register_plugin("BlackJack", VERSION, "DusT")
    register_clcmd("say /blackjack", "blackJackMain")
    register_clcmd("say /bj", "blackJackMain")
    
    register_cvar( "AmX_DusT", "BlackJack", FCVAR_SERVER | FCVAR_SPONLY );
    
    //bind_pcvar_num(create_cvar("amx_blackjack_cash_trigger", "10000", .description = "If they win more than this, it'll be shown to all that he won"), p_cash_ads)
    p_cash_ads = register_cvar("amx_blackjack_cash_trigger", "10000")
    p_only_dead = register_cvar("amx_blackjack_dead_only", "1")
    p_allow_spec = register_cvar("amx_blackjack_allow_spec", "1")
    p_min_bet = register_cvar( "amx_blackjack_min_bet", "1000")
}

public blackJackMain( id ){
    if(!CanPlay( id ))
        return PLUGIN_HANDLED
    if(!check_bit(bFinished, id) && !check_bit(bStarted, id)){
        addCash( id, get_pcvar_num(p_min_bet), RAISE )
        showBetMenu( id, 100 )
        return PLUGIN_HANDLED
    }else if(check_bit(bStarted, id)){
        showMenuCards( id )
        return PLUGIN_HANDLED 
    }
    static menuid, title[64]
    formatex(title, charsmax(title), "BlackJack Game ^n^nLast game you %s %s%d.^n", check_bit(bLast, id) ? "won":(check_bit(bDraw, id))? "draw betting":"lost", CASH_SYMBOL, gCash[id])
    menuid = menu_create(title, "mainHandler")
    menu_additem(menuid, "Show the table")
    menu_additem(menuid, "Play again")

    menu_display( id, menuid, 0)
    
    return PLUGIN_HANDLED
}

public getValue( id, type ){
    new value, dummy, aces
    if(!type){
        for(new i = 0; i < MAX_PLAYER_CARDS; i++){
            if(!gCards[id][i])
                break
            dummy = (gCards[ id ][ i ] / 4 ) + 1
            if( dummy >= 11 && dummy <= 13)
                dummy = 10 
            if(dummy == 14){
                dummy = 11
                aces++
            }
            value += dummy
        }
    }
    else{
        for(new i = 0; i < MAX_PC_CARDS; i++){
            if(!gPc[id][i])
                break
            dummy = (gPc[ id ][ i ] / 4 ) + 1
            if( dummy >= 11 && dummy <= 13)
                dummy = 10 
            if(dummy == 14){
                dummy = 11
                aces++
            }
            value += dummy
        }
    }
    while(value > 21 && aces ){
        value -= 10
        aces-- 
    }
    return value
}
public getSpace( id, type ){
    static free
    if(!type){
        for(free = 0; free < MAX_PLAYER_CARDS; free++){
            if(!gCards[id][free])
                return free
        }
    }
    else{
        for(free = 0; free < MAX_PC_CARDS; free++){
            if(!gPc[id][free])
                return free
        }
    }
    return -1
}
public mainHandler( id, menuid, item ){
    if(is_user_connected(id)){
        switch( item ){
            case 0: showMotd( id )
            case 1: {
                resetGame( id )
                addCash( id, get_pcvar_num(p_min_bet), RAISE )
                showBetMenu( id, 100 )
            }
        }
    }
    menu_destroy( menuid )
    return PLUGIN_HANDLED
}
bool:CanPlay( id, bool:messages = true, bool:onlyBet = false ){
    if(!onlyBet && !check_bit(bStarted, id) && get_pcvar_num(p_only_dead) && (is_user_alive(id) || (!get_pcvar_num(p_allow_spec) && !(1<=get_user_team(id)<=2)))){
        if(messages)
            client_print_color(id, print_team_red, "^3[BLACKJACK]^1 You must be dead%s to play.", !get_pcvar_num(p_allow_spec)? " and not spectator":"")
        return false
    }
    if( (get_user_cash(id)) < get_pcvar_num(p_min_bet) && gCash[id] < get_pcvar_num(p_min_bet)){
        if(messages)
            client_print_color(id, print_team_red, "^3[BLACKJACK]^1 You can play only if you bet equal or more than %s%d.", CASH_SYMBOL, get_pcvar_num(p_min_bet))
        return false
    }
    return true
}
public showBetMenu( id, bet ){
    static menuid, dummy[64], dummy2[50], buf[16]
    num_to_str(bet, buf, charsmax(buf))
    formatex(dummy, charsmax(dummy), "BlackJack Game ^n^nBet Value: %s%d", CASH_SYMBOL, gCash[id])
    menuid = menu_create(dummy, "betMenuHandler")
    formatex(dummy, charsmax(dummy), "Raise the bet in %s%d", CASH_SYMBOL, bet)
    menu_additem(menuid, dummy, buf, get_user_cash(id)>=bet? 0:disableItem)
    formatex(dummy, charsmax(dummy), "Lower the bet in %s%d^n",CASH_SYMBOL, bet)
    menu_additem(menuid, dummy, _, gCash[id]>=bet? 0:disableItem)
    menu_additem(menuid, "Bigger Unit", _, bet >= MAX_UNIT? disableItem:0)
    menu_additem(menuid, "Lower Unit^n", _, bet <= MIN_UNIT? disableItem:0 )
    menu_additem(menuid, "Bet all", _, get_user_cash(id)<=0? disableItem:0)
    formatex(dummy2, charsmax(dummy2), " \r(You need to bet at least %s%d)", CASH_SYMBOL, get_pcvar_num(p_min_bet))
    formatex(dummy, charsmax(dummy), "Start%s", !CanPlay(id, false, true)? dummy2:"")
    menu_additem(menuid, dummy, _, CanPlay(id, false, true)? 0:disableItem)
    //remove pagination
    //menu_setprop(menuid, MPROP_PERPAGE, 0)
    //remove exit button as it bugs out if pagination is removed
    //menu_setprop(menuid, MPROP_EXIT, MEXIT_NEVER)

    menu_display( id, menuid, 0 )

    return PLUGIN_HANDLED

}

public betMenuHandler( id, menuid, item ){
    if(is_user_connected(id)){
        new name[32], dummy, buf[16]
        menu_item_getinfo(menuid, 0, dummy, buf, charsmax(buf), name, charsmax(name), dummy)
        new amount = str_to_num(buf)
        switch(item){
            case 0: addCash( id, amount, RAISE )
            case 1: addCash( id, amount, DOWN )
            case 2: amount *= 10
            case 3: amount /= 10
            case 4: addCash( id, 0, RAISE )
            case 5: startGame( id )
            case MENU_EXIT: {
                set_user_cash( id, get_user_cash( id ) + gCash[ id ])
                gCash[ id ] = 0
            }
        }
        if( item < 5 && item != MENU_EXIT){
            showBetMenu( id, amount )
        }
    }
    menu_destroy( menuid )
    return PLUGIN_HANDLED
}
public addCash( id, amount, type ){
    if(!amount){
        amount = get_user_cash( id )
    }
    if( type ){
        if( get_user_cash( id ) < amount ){
            client_print_color(id, print_team_red, "^3[BLACKJACK]^1 You don't have enough cash for this operation.")
            return PLUGIN_HANDLED
        }
        gCash[ id ] += amount
        set_user_cash( id, get_user_cash( id ) - amount)
    }
    else{
        if( gCash[ id ] < amount ){
            client_print_color(id, print_team_red, "^3[BLACKJACK]^1 You can't do this operation.")
            return PLUGIN_HANDLED
        }
        gCash[ id ] -= amount
        set_user_cash( id, get_user_cash( id ) + amount)
    }
    return PLUGIN_HANDLED
}
public startGame( id ){
    if(!gCash[ id ]){
        client_print_color(id, print_team_red, "^3[BLACKJACK]^1 You can't play without betting some cash.")
        showBetMenu( id, 100 )
        return PLUGIN_HANDLED
    }
    if(!CanPlay(id, true, true))
        return PLUGIN_HANDLED
    for( new i = 0; i < 2; i++){
        gCards[ id ][ i ] = getRandom( id )
        gPc[ id ][ i ] = getRandom( id )
    }
    set_bit(bStarted, id );
    clear_bit(bLast, id);
    clear_bit(bDraw, id);
    if(getValue(id, PLAYER) == 21)
        stopCards( id )
    else
        showMenuCards( id )
    showMotd( id )
    
    return PLUGIN_HANDLED
}
public showMenuCards( id ){
    static menuid
    menuid = menu_create("BlackJack Game", "menuCardsHandler")
    menu_additem(menuid, "Show the table")
    menu_additem(menuid, "Get new card")
    menu_additem(menuid, "Double down", _, (get_user_cash(id) >= gCash[id])? 0:disableItem)
    menu_additem(menuid, "Stop")
    menu_display( id, menuid, 0)
    return PLUGIN_HANDLED
}
public menuCardsHandler( id, menuid, item ){
    if(is_user_connected( id )){
        switch(item){
            case 0: {
                showMotd( id )
                showMenuCards( id )
            }
            case 1:{
                gCards[ id ][ getSpace( id, PLAYER )] = getRandom( id )
                if(getValue(id, PLAYER) > 21){
                    setVictory( id, NPC )
                
                }else if(getValue(id, PLAYER) == 21){
                    stopCards( id )
                }
                else{
                    showMotd( id ) 
                    showMenuCards( id )
                }    
            }
            case 2:{
                set_user_cash( id, get_user_cash( id ) - gCash[id])
                gCash[ id ] *= 2
                gCards[ id ][ getSpace( id, PLAYER )] = getRandom( id )
                if(getValue(id, PLAYER) > 21){
                    setVictory( id, NPC )
                }else {
                    stopCards( id )
                    showMotd( id ) 
                }    
            }
            case 3: stopCards( id )
        }
    }
    menu_destroy( menuid )
    return PLUGIN_HANDLED 
}

public setVictory( id, type ){
    if(type == PLAYER){
        gCash[id] *= 2
        set_user_cash( id, get_user_cash( id ) + gCash[ id ])
        //errors if i don't put ";" *shrug*
        set_bit(bLast, id);
        if(gCash[id] > get_pcvar_num(p_cash_ads)){
            client_print_color(0, print_team_red, "^3[BLACKJACK]^1 Amazing! '%n' just won %s%d on the ^3BlackJack^1 game!", id, CASH_SYMBOL, gCash[ id ])
        }
    }
    else if(type == NPC){
        clear_bit(bLast, id);
    }
    else{
        clear_bit(bLast, id);
        set_bit(bDraw, id);
        set_user_cash( id, get_user_cash( id ) + gCash[ id ])
    }
    clear_bit(bStarted, id);
    set_bit(bFinished, id);

    showMotd( id )
    playAgain( id )
}
public playAgain( id ){
    static menuid 
    menuid = menu_create("Play Again?", "playAgainHandler")
    menu_additem(menuid, "Yes")
    menu_additem(menuid, "No")
    menu_display(id, menuid, 0)
    return PLUGIN_HANDLED 
}
public playAgainHandler( id, menuid, item ){
    if(is_user_connected( id ) && item == 0 && CanPlay(id)){
        resetGame( id )
        addCash( id, get_pcvar_num(p_min_bet), RAISE )
        showBetMenu( id, 100 )
    }
    menu_destroy( menuid )
    return PLUGIN_HANDLED 
}
public stopCards( id ){
    set_bit(bShow, id)
    while(getValue(id, NPC) < 17){
        gPc[ id ][ getSpace( id, NPC )] = getRandom( id )
    }
    new valpc, valpl 
    valpc = getValue(id, NPC)
    valpl = getValue(id, PLAYER)
    if(valpc > 21)
        setVictory( id, PLAYER )
    else if(valpc == valpl)
        setVictory( id, 2 )
    else if(valpl > valpc)
        setVictory( id, PLAYER )
    else
        setVictory( id, NPC )
}
//0 player, 1 pc
public getRandom( id ){
    new num
    do{
        num = random_num(4, 55)
    }
    while(!checkCard( id, num ))
    return num
}
public checkCard( id, card ){
    for(new i = 0; i < MAX_PLAYER_CARDS; i++){
        if(gCards[id][i] == card)   return false
        if(i < MAX_PC_CARDS){
            if(!gCards[id][i] && !gPc[id][i])   return true
            if(gPc[id][i] == card)  return false
        }
    }
    return true
}
public showMotd( id ){
    static msg[1500], len
    len = 0
    len += formatex(msg[len], charsmax(msg), "<head><style>img{  width: 100px; height: 115px; }</style></head><body style=^"background-color: #b3b3b3;^">")

    len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, (check_bit(bShow, id))? g_Cards[gPc[id][0]]:BACK_CARD)
    len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, g_Cards[gPc[id][1]])

    for(new i = 2; i < MAX_PC_CARDS; i++){
        if(!gPc[id][i])
            break
        len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, g_Cards[gPc[id][i]])
    }
    new str[3]
    num_to_str(getValue(id, NPC), str, charsmax(str))
    len += formatex(msg[len], charsmax(msg), "<br><b>Dealer</b> - Points:  <b>%s</b><br>", check_bit(bShow, id)? str:"HIDDEN")
    len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, g_Cards[gCards[id][0]])
    len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, g_Cards[gCards[id][1]])
    for(new i = 2; i < MAX_PLAYER_CARDS; i++){
        if(!gCards[id][i])
            break
        len += formatex(msg[len], charsmax(msg), "<img src='%s/%s.png'>", DIR_CARDS, g_Cards[gCards[id][i]])
    }
    len += formatex(msg[len], charsmax(msg), "<br><br>Player:  <b>%n</b> - Points:  <b>%d</b><br><br>", id, getValue( id, PLAYER ))
    if(!check_bit(bStarted, id)){
        if(check_bit(bLast, id))
            len += formatex(msg[len], charsmax(msg), "<font color=red><b>You Won %s%d!</b>", CASH_SYMBOL, gCash[id])
        else{
            if(check_bit(bDraw, id))
                len += formatex(msg[len], charsmax(msg), "<font color=red><b>DRAW. You'll have back your %s%d</b>", CASH_SYMBOL, gCash[id])
            else
                len += formatex(msg[len], charsmax(msg), "<font color=red><b>You lost %s%d!</b>", CASH_SYMBOL, gCash[id])
        }
    }
    len += formatex(msg[len], charsmax(msg), "</body>")
    show_motd(id, msg, "BlackJack")
}
public resetGame( id ){
    for(new i = 0; i < MAX_PLAYER_CARDS; i++){
        gCards[ id ][ i ] = 0
        if( i < MAX_PC_CARDS){
            gPc[ id ][ i ] = 0
        }
    }
    clear_bit(bLast, id);
    clear_bit(bShow, id);
    clear_bit(bDraw, id);
    clear_bit(bStarted, id);
    clear_bit(bFinished, id);
    gCash[ id ] = 0
}

public client_disconnected( id ){
    if( !check_bit(bLast, id) && gCash[id]){
        set_user_cash( id, get_user_cash( id ) + gCash[ id ])
    }
    resetGame( id )
}
