<?xml version="1.0"?>
<!-- return url + title per line -->
<stylesheet version="1.0"
  xmlns="http://www.w3.org/1999/XSL/Transform">
  <output method="text"/>
  <template match="/">
    <apply-templates select="/rss/channel/item/enclosure"/>
  </template>
  <template match="enclosure">
    <value-of select="@url"/><text> </text><value-of select="../title"/><text>&#10;</text>
  </template>
</stylesheet>
