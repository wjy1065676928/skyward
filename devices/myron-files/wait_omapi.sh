#!/system/bin/sh
# Hold the weaver's start until the element's service has answered once.
# The service registers itself as soon as its program is up, but it is only
# able to name the element after that program has connected to it, and a
# weaver that asks in that gap is turned away and ends. Asking here first,
# and only once it answers going on, keeps the weaver from being spent on a
# service that is not ready to give it anything.
set -e
i=0
while [ "$i" -lt 60 ]; do
    if dumpsys -l 2>/dev/null | grep -q "android.se.omapi.ISecureElementService/default"; then
        sleep 3
        exit 0
    fi
    sleep 0.5
    i=$((i + 1))
done
# The service directory lists it whatever its program's state, so the list
# alone is not the answer: wait the whole time out and go on regardless,
# which is what happens without this at all.
sleep 3
exit 0
