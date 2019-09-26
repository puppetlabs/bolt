<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<!-- This file added for SourceForge bug report #2962813 --> 
<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:topicpull="http://dita-ot.sourceforge.net/ns/200704/topicpull"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                exclude-result-prefixes="topicpull ditamsg ">
  
  <!-- When cross referencing a step, skip any stepsection elements in the step count -->
  <xsl:template match="*[contains(@class,' task/step ')]" mode="topicpull:li-linktext">
    <xsl:number level="multiple"
      count="*[contains(@class,' task/step ')]" format="1.a.i.1.a.i.1.a.i"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' task/substep ')]" mode="topicpull:li-linktext">
    <xsl:number level="multiple"
      count="*[contains(@class,' topic/ol ')]/*[contains(@class,' topic/li ')][not(contains(@class,' task/stepsection '))]" format="1.a.i.1.a.i.1.a.i"/>
  </xsl:template>

</xsl:stylesheet>
