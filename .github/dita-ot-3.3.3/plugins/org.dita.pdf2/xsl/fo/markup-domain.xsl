<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                version="2.0">
  
  <xsl:template match="*[contains(@class, ' markup-d/markupname ')]">
    <fo:inline xsl:use-attribute-sets="markupname">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:inline>
  </xsl:template>
  
</xsl:stylesheet>
