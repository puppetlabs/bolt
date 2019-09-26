<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:import href="plugin:org.dita.html5:xsl/syntax-braces.xsl"/>

  <xsl:template match="*[contains(@class, ' pr-d/codeblock ')]" name="topic.pr-d.codeblock">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="spec-title-nospace"/>
  
    <pre>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setscale"/>
      <xsl:call-template name="setidaname"/>
  
      <code>
        <xsl:apply-templates/>
      </code>
    </pre>
  
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/codeph ')]" name="topic.pr-d.codeph">
   <code>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
    </code>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/kwd ')]" name="topic.pr-d.kwd">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class">
        <xsl:value-of select="'kwd',
                              'defkwd'[current()/@importance = 'default']"
                      separator=" "/>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/var ')]" name="topic.pr-d.var">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'var'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/synph ')]" name="topic.pr-d.synph">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'synph'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/oper ')]" name="topic.pr-d.oper">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'oper'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/delim ')]" name="topic.pr-d.delim">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'delim'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/sep ')]" name="topic.pr-d.sep">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'sep'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/repsep ')]" name="topic.pr-d.repsep">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'repsep'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/option ')]" name="topic.pr-d.option">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'option'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/parmname ')]" name="topic.pr-d.parmname">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'parmname'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/apiname ')]" name="topic.pr-d.apiname">
   <span>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'apiname'"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>

</xsl:stylesheet>
