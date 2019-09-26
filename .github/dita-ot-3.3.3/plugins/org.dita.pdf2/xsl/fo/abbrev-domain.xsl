<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2012 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:opentopic="http://www.idiominc.com/opentopic"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                version="2.0"
                exclude-result-prefixes="xs opentopic dita-ot ditamsg">
  
  <xsl:param name="first-use-scope" select="'document'"/>
  
  <xsl:key name="abbreviated-form-keyref"
           match="*[contains(@class, ' abbrev-d/abbreviated-form ')]
                   [empty(ancestor::opentopic:map) and empty(ancestor::*[contains(@class, ' topic/title ')])]
                   [@keyref]"
           use="@keyref"/>
  
  <xsl:template match="*[contains(@class,' abbrev-d/abbreviated-form ')]" name="topic.abbreviated-form">
    <xsl:variable name="keys" select="@keyref"/>
    <xsl:variable name="target" select="key('id', substring(@href, 2))[1]" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$keys and $target/self::*[contains(@class,' glossentry/glossentry ')]">
        <xsl:call-template name="topic.term">
          <xsl:with-param name="contents">
            <xsl:variable name="use-abbreviated-form" as="xs:boolean">
              <xsl:apply-templates select="." mode="use-abbreviated-form"/>
            </xsl:variable>
            <xsl:choose>
              <xsl:when test="$use-abbreviated-form">
                <xsl:apply-templates select="$target" mode="getMatchingAcronym"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="$target" mode="getMatchingSurfaceForm"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-abbreviated-form">
          <xsl:with-param name="keys" select="$keys"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Should abbreviated form of glossary entry be used -->
  <xsl:template match="*" mode="use-abbreviated-form" as="xs:boolean">
    <xsl:variable name="first-use-scope-root" as="element()">
      <xsl:call-template name="get-first-use-scope-root"/>
    </xsl:variable>
    <xsl:sequence select="not(generate-id(.) = generate-id(key('abbreviated-form-keyref', @keyref, $first-use-scope-root)[1]))"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' topic/copyright ')]//*" mode="use-abbreviated-form" as="xs:boolean">
    <xsl:sequence select="false()"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' topic/title ')]//*" mode="use-abbreviated-form" as="xs:boolean">
    <xsl:sequence select="true()"/>
  </xsl:template>  

  <!-- Get element to use as root when  -->
  <xsl:template name="get-first-use-scope-root" as="element()">
    <xsl:choose>
      <xsl:when test="$first-use-scope = 'topic'">
        <xsl:sequence select="ancestor::*[contains(@class, ' topic/topic ')][1]"/>
      </xsl:when>
      <xsl:when test="$first-use-scope = 'chapter'">
        <xsl:sequence select="ancestor::*[contains(@class, ' topic/topic ')][position() = last()]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="/*"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*" mode="getMatchingSurfaceForm">
    <xsl:variable name="glossSurfaceForm" select="*[contains(@class, ' glossentry/glossBody ')]/*[contains(@class, ' glossentry/glossSurfaceForm ')]"/>
    <xsl:choose>
      <xsl:when test="$glossSurfaceForm">
        <xsl:apply-templates select="$glossSurfaceForm/node()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="*[contains(@class, ' glossentry/glossterm ')]/node()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*" mode="getMatchingAcronym">
    <xsl:variable name="glossAcronym" select="*[contains(@class, ' glossentry/glossBody ')]/*[contains(@class, ' glossentry/glossAlt ')]/*[contains(@class, ' glossentry/glossAcronym ')]"/>
    <xsl:choose>
      <xsl:when test="$glossAcronym">
        <xsl:apply-templates select="$glossAcronym[1]/node()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="*[contains(@class, ' glossentry/glossterm ')]/node()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*" mode="ditamsg:no-glossentry-for-abbreviated-form">
    <xsl:param name="keys"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX060W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$keys"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
