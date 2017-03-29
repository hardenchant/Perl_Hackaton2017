# Base commands

## Message 'Test' to: #someroom
> Test

```json
{
    "cmd": "MSG",
    "data": {
        "seq": 123456,
        "text": "Test",
        "to": "#someroom"
    },
    "v": 1
}
```

## Change self nickname (command AUTH without password)
> /nick NickName

```json
{
    "cmd": "AUTH",
    "data": {
        "nick": "NickName",
        "seq": 123123
    },
    "v": 1
}
```

## Change self nickname (command AUTH with password validation)
> /nick NickName pass

```json
{
    "cmd": "AUTH",
    "data": {
        "nick": "NickName",
        "password": "passwd",
        "seq": 123123
    },
    "v": 2
}
```

## Switch default state to room #test (client only)
> /room #test

Send no packet, only client state

## Message 'Test' to: #test (because default was set to #test)
> Test

```json
{
    "cmd": "MSG",
    "data": {
        "seq": 123123,
        "text": "Test",
        "to": "#test"
    },
    "v": 1
}
```

## Message 'Test' to: #all
> /msg #all Test

```json
{
    "cmd": "MSG",
    "data": {
        "seq": 123123,
        "text": "Test",
        "to": "#all"
    },
    "v": 1
}
```

## Message 'Test' to: @NickName
> /msg @NickName Test

```json
{
    "cmd": "MSG",
    "data": {
        "seq": 123123,
        "text": "Test",
        "to": "@NickName"
    },
    "v": 1
}
```

---

# Rooms v1

## JOIN room #someroom (create, if room does not exist)
> /join #someroom

```json
{
    "cmd": "JOIN",
    "data": {
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```


## LEAVE room #someroom (or current default room)
> /part [ #someroom ] | /leave [ #someroom ]

```json
{
    "cmd": "PART",
    "data": {
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```

## KICK user @NickName from room #soomroom (or current default room)
> /kick @NickName [, #someroom]

```json
{
    "cmd": "KICK",
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```


## BAN user @NickName in room #someroom (or current default room)
> /ban @NickName [, #someroom]

```json
{
    "cmd": "BAN",
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```


## UNBAN user @NickName in room #someroom (or current default room)
> /unban @NickName [, #someroom]

```json
{
    "cmd": "UNBAN",
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```


## Change TITLE of #someroom (or current default room)
> /title [ #someroom ] Title

```json
{
    "cmd": "TITLE",
    "data": {
        "room": "#someroom",
        "seq": 123123,
        "title": "Title"
    },
    "v": 1
}
```


## Show MEMBERS list of #someroom
> /members [#someroom]

```json
{
    "cmd": "MEMBERS",
    "data": {
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```


## Enable/disable moderation MODE in room #someroom
> /mode [#someroom] +m
> /mode [#someroom] -m

```json
{
    "cmd": "MODE",
    "data": {
        "moderated": true,
        "room": "#someroom",
        "seq": 123123
    },
    "v": 1
}
```

---

# Rooms v2: Roles

## Allow/deny user @NickName send messages to room #someroom
> /grant [#someroom] @NickName +v(?:|oice)
> /grant [#someroom] @NickName -v(?:|oice)

```json
{
    "cmd": "GRANT",
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123,
        "voice": true
    },
    "v": 2
}
```

## Set role (admin/moderator/guest) for user @NickName in room #someroom
> /grant [#someroom] @NickName role a(?:|dmin)
> /grant [#someroom] @NickName role m(?:|oderator)
> /grant [#someroom] @NickName role g(?:|uest)

```json
{
    "cmd": "GRANT",
    "data": {
        "nick": "@NickName",
        "role": "admin",
        "room": "#someroom",
        "seq": 123123
    },
    "v": 2
}
```

---

# Events

## Error from server

* Error: **error message**

```json
{
    "data": {
        "seq": 123123,
        "text": "error message"
    },
    "event": "ERROR",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Incoming message into room #all

* #all> @User: Hello!

```json
{
    "data": {
        "from": "@User",
        "seq": 123123,
        "text": "Hello!",
        "to": "#all"
    },
    "event": "MESSAGE",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Incoming private message from @User to @Someone

* PRIV> @User: Hello!

```json
{
    "data": {
        "from": "@User",
        "seq": 123123,
        "text": "Hello!",
        "to": "@Someone"
    },
    "event": "MESSAGE",
    "timestamp": 1490644009,
    "v": "1"
}
```

## Set nick for requester
* Your name was (set|changed) to **@YourNickname**

```json
{
    "data": {
        "nick": "@YourNickname",
        "seq": 123123
    },
    "event": "NICK",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Somebody set nick
* User **@OldNickName** changed name to **@NewNickName**

```json
{
    "data": {
        "from": "@OldNickName",
        "nick": "@NewNickName"
    },
    "event": "RENAME",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Info by room
* Room **#someroom**: *Title*. Members: !admin1, %moderator1, +voiced1, guest1

```json
{
    "data": {
        "members": [
            {"nick":"@User1","role":"admin"},             /* ! */
            {"nick":"@User2","role":"moderator"},         /* % */
            {"nick":"@User3","role":"guest","voice":true},/* + */
            {"nick":"@User4","role":"guest"},
            {"nick":"@User5","role":"guest"}
        ],
        "moderated": false,
        "room": "#someroom",
        "seq": 123
    },
    "event": "ROOM",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Somebody join to room
* User **@NickName** joined the room **#someroom**

```json
{
    "data": {
        "nick": "@NickName",
        "room": "#someroom"
    },
    "event": "JOIN",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Someboby leave from room
* User **@NickName** left the room **#someroom**

```json
{
    "data": {
        "nick": "@Nickname",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "PART",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Change room title 
* **#someroom**: *Title*

```json
{
    "data": {
        "from": "@User",
        "room": "#someroom",
        "seq": 123123,
        "title": "Title"
    },
    "event": "TITLE",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Change moderate status of room
* Room **#someroom** was set to mode moderated
* Room **#someroom** was set to free speech mode

```json
{
    "data": {
        "moderated": true,
        "room": "#someroom",
        "seq": 123123
    },
    "event": "MODE",
    "timestamp": 1490644008,
    "v": "1"
}
{
    "data": {
        "moderated": false,
        "room": "#someroom",
        "seq": 123123
    },
    "event": "MODE",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Change user voice status 
* User **@NickName** was granted with voice in **#someroom**
* User **@NickName** was devoiced in **#someroom**

```json
{
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123,
        "voice": true
    },
    "event": "GRANT",
    "timestamp": 1490644008,
    "v": "1"
}
{
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123,
        "voice": false
    },
    "event": "GRANT",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Grant admin role to user
* User **@NickName** became an admin of **#someroom**
* User **@NickName** became an moderator of **#someroom**
* User **@NickName** became a guest of **#someroom**

```json
{
    "data": {
        "nick": "@NickName",
        "role": "admin",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "GRANT",
    "timestamp": 1490644008,
    "v": "1"
}
{
    "data": {
        "nick": "@NickName",
        "role": "moderator",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "GRANT",
    "timestamp": 1490644008,
    "v": "1"
}
{
    "data": {
        "nick": "@NickName",
        "role": "guest",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "GRANT",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Kick user from room
* User **@NickName** was kicked from **#someroom**

```json
{
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "KICK",
    "timestamp": 1490644008,
    "v": "1"
}
```

## Ban user in room
* User **@NickName** was banned in **#someroom**

```json
{
    "data": {
        "nick": "@NickName",
        "room": "#someroom",
        "seq": 123123
    },
    "event": "BAN",
    "timestamp": 1490644008,
    "v": "1"
}
```
