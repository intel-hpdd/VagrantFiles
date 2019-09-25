mkdir -p /tmp/iml-install
cd /tmp/iml-install
curl -L $1 | tar zx --strip 1
yum install -y expect
/usr/bin/expect << EOF
set timeout -1

spawn ./install --no-dbspace-check

expect "Username: "

send -- "admin\r"

expect "Password: "

send -- "lustre\r"

expect "Confirm password: "

send -- "lustre\r"

expect "Email: "

send -- "\r"

expect "NTP Server *: "

send -- "\r"

expect eof
EOF