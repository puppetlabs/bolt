<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2019 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  version="2.0"
  exclude-result-prefixes="xs dita-ot">
  
  <!-- By default in XEP, rotated table entries will extend to the end of the page, unless a height is provided for the container.
       To enable rotation, explicitly set the height (and optionally width) as follows:
       1) Uncomment the fo:block-container
       2) Adjust the height and width values to either
       2a) An appropriate default that is acceptable for all of your rotated cells, or
       2b) A specific or calculated value based on the cell content --> 
  <xsl:template match="*[contains(@class, ' topic/thead ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
    <!--<fo:block-container reference-orientation="90" width="150px" height="80px">-->
    <fo:block xsl:use-attribute-sets="thead.row.entry__content">
      <xsl:call-template name="processEntryContent"/>
    </fo:block>
    <!--</fo:block-container>-->
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/tbody ')]/*[contains(@class, ' topic/row ')]/*[contains(@class, ' topic/entry ')]" mode="rotateTableEntryContent">
    <!--<fo:block-container reference-orientation="90" width="150px" height="80px">-->
    <fo:block xsl:use-attribute-sets="tbody.row.entry__content">
      <xsl:call-template name="processEntryContent"/>
    </fo:block>
    <!--</fo:block-container>-->
  </xsl:template>

</xsl:stylesheet>
