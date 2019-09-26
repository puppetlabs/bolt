<?xml version="1.0" encoding="utf-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">              

  <xsl:function name="dita-ot:normalize" as="xs:anyURI">
    <xsl:param name="uri" as="xs:anyURI"/>
    <xsl:variable name="normalized">
      <xsl:call-template name="dita-ot:normalize-uri">
        <xsl:with-param name="src" select="tokenize($uri, '/')"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="xs:anyURI($normalized)"/>
  </xsl:function>
  
  <xsl:template name="dita-ot:normalize-uri" as="xs:string">
    <xsl:param name="src" as="xs:string*"/>
    <xsl:param name="res" select="()" as="xs:string*"/>
    
    <xsl:choose>
      <xsl:when test="empty($src)">
        <xsl:value-of select="$res" separator="/"/>
      </xsl:when>
      <xsl:when test="$src[1] = '.'">
        <xsl:call-template name="dita-ot:normalize-uri">
          <xsl:with-param name="src" select="$src[position() ne 1]"/>
          <xsl:with-param name="res" select="$res"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$src[1] = '..' and exists($res) and not($res[position() eq last()] = ('..', ''))">
        <xsl:call-template name="dita-ot:normalize-uri">
          <xsl:with-param name="src" select="$src[position() ne 1]"/>
          <xsl:with-param name="res" select="$res[position() ne last()]"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="dita-ot:normalize-uri">
          <xsl:with-param name="src" select="$src[position() ne 1]"/>
          <xsl:with-param name="res" select="($res, $src[1])"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="dita-ot:relativize" as="xs:anyURI">
    <xsl:param name="base" as="xs:anyURI"/>
    <xsl:param name="uri" as="xs:anyURI"/>
    
    <xsl:variable name="b-scheme" select="substring-before($base, ':')" as="xs:string"/>
    <xsl:variable name="u-scheme" select="substring-before($uri, ':')" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$b-scheme ne $u-scheme">
        <xsl:sequence select="$uri"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="b" select="tokenize(substring-after($base, ':'), '/')" as="xs:string+"/>
        <xsl:variable name="u" select="tokenize(substring-after($uri, ':'), '/')" as="xs:string+"/>   
        <xsl:sequence select="dita-ot:relativize.strip-and-prefix($b, $u)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="dita-ot:relativize.strip-and-prefix" as="xs:anyURI">
    <xsl:param name="a" as="xs:string+"/>
    <xsl:param name="b" as="xs:string+"/>
    <xsl:choose>
      <xsl:when test="$a[1] = $b[1]">
        <xsl:sequence select="dita-ot:relativize.strip-and-prefix($a[position() ne 1], $b[position() ne 1])"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="res" as="xs:string+">
          <xsl:for-each select="$a[position() ne 1]">../</xsl:for-each>
          <xsl:value-of select="$b" separator="/"/>
        </xsl:variable>
        <xsl:sequence select="xs:anyURI(string-join($res, ''))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="dita-ot:strip-fragment" as="xs:string">
    <xsl:param name="href" as="xs:string"/>
    <xsl:value-of select="if (contains($href, '#')) then substring-before($href, '#') else $href"/>
  </xsl:function>

  <xsl:function name="dita-ot:resolve" as="xs:anyURI">
    <xsl:param name="base" as="xs:anyURI"/>
    <xsl:param name="uri" as="xs:anyURI"/>
    <xsl:variable name="b" select="tokenize(dita-ot:strip-fragment($base), '/')" as="xs:string+"/>
    <xsl:variable name="u" select="tokenize($uri, '/')" as="xs:string+"/>
    <xsl:variable name="res" as="xs:string+">
      <xsl:call-template name="dita-ot:normalize-uri">
        <xsl:with-param name="src" select="($b[position() ne last()], $u)"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:sequence select="xs:anyURI(string-join($res, '/'))"/>
  </xsl:function>
  
</xsl:stylesheet>
