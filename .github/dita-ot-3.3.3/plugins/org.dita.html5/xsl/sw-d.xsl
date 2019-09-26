<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:template match="*[contains(@class,' sw-d/filepath ')]" name="topic.sw-d.filepath">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'filepath'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/msgph ')]" name="topic.sw-d.msgph">
   <samp>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'msgph'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </samp>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/userinput ')]" name="topic.sw-d.userinput">
   <kbd>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'userinput'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </kbd>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/systemoutput ')]" name="topic.sw-d.systemoutput">
   <samp>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'sysout'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </samp>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/cmdname ')]" name="topic.sw-d.cmdname">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'cmdname'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/msgnum ')]" name="topic.sw-d.msgnum">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'msgnum'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' sw-d/varname ')]" name="topic.sw-d.varname">
   <var>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'varname'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </var>
  </xsl:template>

</xsl:stylesheet>
