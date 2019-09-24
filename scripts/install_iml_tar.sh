cd /tmp
curl -L $1 | tar zx
cd /tmp/$2
./install --no-dbspace-check
chroma-config setup admin lustre localhost --no-dbspace-check