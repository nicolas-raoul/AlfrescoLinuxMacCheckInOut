#!/bin/sh
##########################################
# Checkout an Alfresco document.
# 2011/04/12
# Nicolas Raoul - Aegif
##########################################
# TODO
# - Deal with cases: ./checkout ../file  and  ./checkout /dir/file
# - Implement checkin
##########################################
# Configuration
LOCAL_ROOT="/home/nico/" #"/mount/cifs"
REMOTE_ROOT="http://localhost:8080/alfresco/s/cmis/s/workspace://SpacesStore/i/f4d348a9-b563-45c0-a154-c083ea3da879" # noderef with a "i/" inserted.
##########################################


LOCAL_FILE=$1
echo "Checking out file ${LOCAL_FILE}"
LOCAL_PATH=${PWD}

SED_LOCAL_ROOT=$(echo $LOCAL_ROOT | sed -e "s#\/#\\\/#g")
RELATIVE_PATH=$(echo $LOCAL_PATH | sed -e "s/$SED_LOCAL_ROOT//")
echo "Relative path: $RELATIVE_PATH"

PATH_ELEMENTS=$(echo $RELATIVE_PATH | sed -e "s#\/# #g")
echo $PATH_ELEMENTS

REMOTE_CURSOR=${REMOTE_ROOT}

for PATH_ELEMENT in $PATH_ELEMENTS $LOCAL_FILE
do
    echo "Moving to path element [$PATH_ELEMENT]"
    curl -uadmin:admin "$REMOTE_CURSOR/children" > /tmp/output
    # TODO: Find a better way to get the path element's noderef. For now we guess it is within 9999999 lines before its title.
    # Better solution on http://unix.stackexchange.com/questions/11305
    REMOTE_CURSOR=$(grep -B9999999 "<title>$PATH_ELEMENT</title>" /tmp/output | grep "rel=\"self\"" | tail -n 1 | sed -e "s/.*href=\"//g" | sed -e "s/\"\/>//g")
    echo "REMOTE_CURSOR:$REMOTE_CURSOR"
done

echo "Checking out [$LOCAL_FILE]"

# TODO find the noderef by navigating the path from LOCAL_ROOT to LOCAL_PATH, while following along remotely.
NODEREF=$(echo $REMOTE_CURSOR | sed -e "s/.*s\/cmis\/s\///g" -e "s/workspace:/workspace:\/\//g" -e "s/i\///g")
echo $NODEREF
# "workspace://SpacesStore/ebc57ec5-e817-4aa4-9217-936b3f355048"

echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<entry xmlns=\"http://www.w3.org/2005/Atom\" xmlns:cmisra=\"http://docs.oasis-open.org/ns/cmis/restatom/200908/\" xmlns:cmis=\"http://docs.oasis-open.org/ns/cmis/core/200908/\">
<cmisra:object>
<cmis:properties>
<cmis:propertyId propertyDefinitionId=\"cmis:objectId\">
<cmis:value>${NODEREF}</cmis:value>
</cmis:propertyId>
</cmis:properties>
</cmisra:object>
</entry>
" > /tmp/atomentry.xml

curl -X POST -uadmin:admin "http://localhost:8080/alfresco/s/cmis/checkedout" -H "Content-Type:application/atom+xml;type=entry;charset=UTF-8" -d @/tmp/atomentry.xml > /tmp/checkout-result.xml

# TODO check for errors (for instance because of document associations induced by onetimedownload)

echo "Done"
