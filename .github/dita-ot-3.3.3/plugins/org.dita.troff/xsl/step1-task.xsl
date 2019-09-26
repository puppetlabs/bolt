<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
<xsl:output method="xml"/>

<xsl:template match="*[contains(@class,' task/steps ') or contains(@class,' task/steps-unordered ')]" name="topic.task.steps">
  <xsl:choose>
    <xsl:when test="not(*[2])">
      <block><xsl:call-template name="commonatts"/><xsl:apply-templates/></block>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-imports/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class,' task/step ')]/@importance |
                     *[contains(@class,' task/substep ')]/@importance">
  <xsl:if test=".='optional' or .='required'">
    <text style="bold"><xsl:call-template name="commonatts"/>
      <xsl:if test=".='optional'">
        <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Optional'"/></xsl:call-template>
      </xsl:if>
      <xsl:if test=".='required'">
        <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Required'"/></xsl:call-template>
      </xsl:if>
      <xsl:call-template name="getVariable"><xsl:with-param name="id" select="'ColonSymbol'"/></xsl:call-template>
    </text>
    <xsl:text> </xsl:text>
  </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class,' task/step ')]">
  <xsl:choose>
    <xsl:when test="following-sibling::*|preceding-sibling::*">
      <xsl:variable name="listintro">
        <xsl:choose>
          <xsl:when test="parent::*[contains(@class,' task/steps-unordered ')]">*  </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="get-list-number"/><xsl:text> </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <block leadin="{$listintro}" indent="{string-length($listintro)}">
          <xsl:call-template name="commonatts"/>
          <xsl:if test="parent::*[@compact='yes']">
              <xsl:attribute name="compact">yes</xsl:attribute>
          </xsl:if>
          <xsl:apply-templates select="@importance"/>
          <xsl:apply-templates/>
      </block>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="@importance"/>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class,' task/substep ')]">
  <xsl:variable name="listintro">
    <xsl:apply-templates select="." mode="get-list-number"/><xsl:text> </xsl:text>
  </xsl:variable>
  <block leadin="{$listintro}" indent="{string-length($listintro)}">
      <xsl:call-template name="commonatts"/>
      <xsl:if test="parent::*[@compact='yes']"><xsl:attribute name="compact">yes</xsl:attribute></xsl:if>
      <xsl:apply-templates select="@importance"/>
      <xsl:apply-templates/>
  </block>
</xsl:template>

<xsl:template match="*[contains(@class,' task/choicetable ')]" mode="default-simpletable-headers">
  <xsl:value-of select="$newline"/>
  <thead><xsl:call-template name="commonatts"/>
    <row><xsl:call-template name="commonatts"/>
      <xsl:value-of select="$newline"/>
      <entry><xsl:call-template name="commonatts"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Option'"/>
        </xsl:call-template>
      </entry>
      <xsl:value-of select="$newline"/>
      <entry><xsl:call-template name="commonatts"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Description'"/>
        </xsl:call-template>
      </entry>
    </row>
  </thead>
</xsl:template>


</xsl:stylesheet>
