<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="xs"
                version="2.0">
  
  <xsl:output doctype-public="-//OASIS//DTD DITA Reference//EN"
              doctype-system="reference.dtd"/>
  
  <xsl:strip-space elements="*"/>
  
  <xsl:param name="output-dir.url"/>

  <xsl:template match="/">
    <xsl:call-template name="all"/>
    <xsl:call-template name="separate"/>
  </xsl:template>
  
  <xsl:template name="all">
    <xsl:comment> Generated from plugin source, do not edit! </xsl:comment>
    <reference id="parameters">
      <title outputclass="generated">DITA-OT parameters</title>
      <reference id="all">
        <title>All DITA-OT parameters</title>
        <refbody>
          <section>
            <parml>
              <xsl:for-each select="//transtype/param">
                <xsl:sort select="@name"/>
                <!--xsl:variable name="props" as="xs:string*">
                  <xsl:variable name="params" as="element(param)*">
                    <xsl:apply-templates select=".." mode="inherit"/>
                  </xsl:variable>
                  <xsl:for-each select="$params/../@name">
                    <xsl:sequence select="tokenize(., '\s+')"/>  
                  </xsl:for-each>
                </xsl:variable-->
                <xsl:apply-templates select=".">
                  <!--xsl:with-param name="props" select="string-join(distinct-values($props), ' ')"/-->
                </xsl:apply-templates>
              </xsl:for-each>
            </parml>
          </section>
        </refbody>
      </reference>
    </reference>
  </xsl:template>
  
  <xsl:template name="separate">
    <!--xsl:for-each select="//transtype/param"-->
    <xsl:for-each-group select="//transtype" group-by="@name">
      <xsl:variable name="id" select="current-grouping-key()"/>
      <xsl:message>Writing <xsl:value-of select="$output-dir.url"/>parameters-<xsl:value-of select="$id"/>.dita</xsl:message>
      <xsl:result-document href="{$output-dir.url}/parameters-{$id}.dita"
                           doctype-public="-//OASIS//DTD DITA Reference//EN"
                           doctype-system="reference.dtd">
        <xsl:comment> Generated from plugin source, do not edit! </xsl:comment>
        <reference id="{$id}">
          <title outputclass="generated">
            <xsl:value-of select="current-group()[1]/@desc"/>
            <xsl:text> parameters</xsl:text>
          </title>
          <titlealts>
            <navtitle>
              <xsl:value-of select="current-group()[1]/@desc"/>
            </navtitle>
          </titlealts>
          <shortdesc id="shortdesc"/>
          <refbody>
            <section>
              <parml>
                <xsl:variable name="params" as="element(param)*">
                  <xsl:sequence select="current-group()/param"/>
                  <!--xsl:apply-templates select="." mode="inherit"/-->
                </xsl:variable>
                <xsl:for-each-group select="$params" group-by="@name">
                  <xsl:sort select="@name"/>
                  <xsl:apply-templates select="current-group()[1]">
                    <xsl:with-param name="params" select="current-group()"/>
                  </xsl:apply-templates>                  
                </xsl:for-each-group>
              </parml>
            </section>
          </refbody>
        </reference>
      </xsl:result-document>
    </xsl:for-each-group>
  </xsl:template>
 
  <!--xsl:template match="transtype" mode="inherit" as="element(param)*">
    <xsl:sequence select="param"/>
    <xsl:variable name="extends" as="xs:string?">
      <xsl:choose>
        <xsl:when test="@name = 'base'"/>
        <xsl:when test="@extends">
          <xsl:value-of select="@extends"/>
        </xsl:when>
        <xsl:otherwise>base</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="exists($extends)">
      <xsl:apply-templates select="//transtype[tokenize(@name, '\s+') = $extends]" mode="inherit"/>
    </xsl:if>
  </xsl:template-->

  <xsl:template match="param">
    <xsl:param name="params" select="."/>
    <xsl:param name="props" select="tokenize(../@name, '\s+')" as="xs:string*"/>
    <plentry id="{@name}">
      <xsl:if test="not($props = 'base')">
        <!--xsl:attribute name="props" select="concat('transtype(', string-join($props, ' '), ')')"/-->
        <xsl:attribute name="props" select="string-join($props, ' ')"/>
      </xsl:if>
      <xsl:if test="@deprecated = 'true'">
        <xsl:attribute name="importance">deprecated</xsl:attribute>
      </xsl:if>
      <xsl:if test="@required = 'true'">
        <xsl:attribute name="importance">required</xsl:attribute>
      </xsl:if>
      <pt>
        <parmname>
          <xsl:value-of select="@name"/>
        </parmname>
        <ph>
          <indexterm>
            <parmname><xsl:value-of select="@name"/></parmname>
          </indexterm>
          <indexterm>parameters<indexterm>
            <parmname><xsl:value-of select="@name"/></parmname>
          </indexterm></indexterm>
        </ph>
        <xsl:if test="@deprecated = 'true'">
          <ph>
            <indexterm>deprecated features<indexterm>parameters<indexterm>
                <parmname><xsl:value-of select="@name"/></parmname>
                </indexterm></indexterm>
            </indexterm>
          </ph>
        </xsl:if>
      </pt>
      <pd id="{@name}.desc">
        <xsl:value-of select="@desc"/>
        <xsl:choose>
          <xsl:when test="@type = 'enum' and $params/val/@desc">
            <xsl:text> The following values are supported:</xsl:text>
            <ul>
              <xsl:for-each select="$params/val">
                <li>
                  <option>
                    <xsl:value-of select="."/>
                  </option>
                  <xsl:if test="@default = 'true'">
                    <xsl:text> (default)</xsl:text>
                  </xsl:if>
                  <xsl:text> – </xsl:text>
                  <xsl:value-of select="@desc"/>
                </li>
              </xsl:for-each>
            </ul>
          </xsl:when>
          <xsl:when test="@type = 'enum' and $params/val">
            <xsl:text> The allowed values are </xsl:text>
            <xsl:choose>
              <xsl:when test="count($params/val) gt 2">
                <xsl:for-each select="$params/val">
                  <xsl:if test="position() ne 1">, </xsl:if>
                  <xsl:if test="position() eq last()">and </xsl:if>
                  <option>
                    <xsl:value-of select="."/>
                  </option>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                <xsl:for-each select="$params/val">
                  <xsl:if test="position() ne 1"> and </xsl:if>
                  <option>
                    <xsl:value-of select="."/>
                  </option>
                </xsl:for-each>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="$params/val[@default = 'true']">
              <xsl:text>; the default value is </xsl:text>
              <option>
                <xsl:value-of select="$params/val[@default = 'true']"/>
              </option>
            </xsl:if>
            <xsl:text>.</xsl:text>
          </xsl:when>
        </xsl:choose>
      </pd>
    </plentry>
  </xsl:template>
  
</xsl:stylesheet>
