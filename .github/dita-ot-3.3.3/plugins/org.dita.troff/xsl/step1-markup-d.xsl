<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">
  
  <xsl:template match="*[contains(@class,' markup-d/markupname ')]">
    <text style="tt"><xsl:call-template name="commonatts"/>
      <xsl:apply-templates/>
    </text>
  </xsl:template>

</xsl:stylesheet>
