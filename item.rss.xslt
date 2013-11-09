<?xml version="1.0" encoding="UTF-8"?>
<!--
    filter out a rss-item for a given enclosure (and replace the enclosure url)
    
    $ enclosure="http://raspi-00.local/TV Shows/Tatort/560 Tod unter der Orgel.mp4"
    $ xsltproc -stringparam enclosure "$enclosure" -stringparam now "demo.mp3" rss-item.xslt index.rss
    
    http://www.w3.org/TR/xslt
-->
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    exclude-result-prefixes="xsl"
    version="1.0">
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:template match="/rss">
    <!-- extract single item -->
    <xsl:apply-templates select="channel/item[enclosure/@url = $enclosure]" />
  </xsl:template>

  <xsl:template match="enclosure/@url">
    <!-- replace attribute value -->
    <xsl:attribute name="url"><xsl:value-of  select="$now"/></xsl:attribute>
  </xsl:template>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
