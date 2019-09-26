<!-- 
This file is part of the DITA Open Toolkit project.

Copyright 2007 Shawn McKenzie

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <!-- this template will stip out funky chars used for js variable names -->
  <xsl:template name="stripstring">
    <xsl:param name="jsvarstring"/>
    <!-- this should simply strip strange characters from the param so it can
      be used as a JavaScript variable name -->
    
    <!-- can't use the following chars in xsl, so make vars -->
    <xsl:variable name="apos">'</xsl:variable>
    <xsl:variable name="comma">,</xsl:variable>
    <xsl:variable name="colon">:</xsl:variable>
    <xsl:variable name="gt">&gt;</xsl:variable>
    <xsl:variable name="lt">&lt;</xsl:variable>
    
    <xsl:value-of select="translate(translate(translate(translate(translate(translate($jsvarstring,
      '/\^&amp;|\¬`*.-) (%?$£!+=1234567890[]{}',
      ''), $apos, ''), $comma, ''), $colon, ''), $gt, ''), $lt, '')"/>
    <!-- above does not catch , ' or : -->

    
    <!-- <xsl:variable name="self" 
      select="translate(translate(translate(@navtitle, '/', ''), '.', ''), ' ', '')"/>-->
  </xsl:template>

  
  
  
  

  <xsl:template name="escapestring">
    <xsl:param name="jstextstring"/>
    <!-- this might need recursion. I'll need to escape chars in the output
         so that these symbols , : ' (others?) look like \, \: \' 
         I might need recursion because there may be multiple instances of
      these chars.-->
    
    <!-- can't use the following chars in xsl, so make vars -->
    <xsl:variable name="apos">'</xsl:variable>
    <xsl:variable name="jsapos">\'</xsl:variable>
    <xsl:variable name="comma">,</xsl:variable>
    <xsl:variable name="jscomma">\,</xsl:variable>
    <xsl:variable name="colon">:</xsl:variable>
    <xsl:variable name="jscolon">\:</xsl:variable>
    
    
    <!-- use the strip for testing and escape later -->
    <xsl:value-of select="translate(translate(translate($jstextstring, '/\^&amp;|\¬`*?.-) (%$£!+=', ''),
      $apos, ''), $comma, '')"/>/>
  </xsl:template>

</xsl:stylesheet>
