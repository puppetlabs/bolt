<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2007 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:topicpull="http://dita-ot.sourceforge.net/ns/200704/topicpull"
  xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
  exclude-result-prefixes="topicpull ditamsg">
  
  <!-- Allow fragref without href as long as it has content. -->
  <xsl:template match="*[contains(@class, ' pr-d/fragref ')][not(@href)][text()|*]">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Ensure desc is not pulled into fragref, which does not allow it in base model -->
  <xsl:template match="*[contains(@class,' pr-d/fragref ')]" mode="topicpull:get-stuff_get-shortdesc"/>
  
</xsl:stylesheet>
