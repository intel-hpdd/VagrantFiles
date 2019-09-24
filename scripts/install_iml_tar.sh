mkdir -p /tmp/iml-install
cd /tmp/iml-install
curl -L $1 | tar zx --strip 1
yes [admin, lustre, lustre,,] | ./install --no-dbspace-check