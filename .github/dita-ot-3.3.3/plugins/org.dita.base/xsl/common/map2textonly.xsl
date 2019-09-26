<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="dita-ot"
  >
  
  <xsl:template match="*[contains(@class,' topic/fn ')][ancestor::*[contains(@class,' map/map ')]]"
                mode="dita-ot:text-only"/>
 
</xsl:stylesheet>
