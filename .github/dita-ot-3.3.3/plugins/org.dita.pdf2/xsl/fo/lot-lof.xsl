<?xml version='1.0'?>



<!--
This file is part of the DITA Open Toolkit project.

Copyright 2011 Reuven Weiser

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:dita2xslfo="http://dita-ot.sourceforge.net/ns/200910/dita2xslfo"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
    exclude-result-prefixes="dita-ot opentopic opentopic-index dita2xslfo ot-placeholder"
    version="2.0">
  
  <xsl:variable name="tableset">
    <xsl:for-each select="//*[contains (@class, ' topic/table ')][*[contains(@class, ' topic/title ' )]]">
      <xsl:if test="dita-ot:notExcludedByDraftElement(.)">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:if test="not(@id)">
            <xsl:attribute name="id">
              <xsl:call-template name="get-id"/>
            </xsl:attribute>
          </xsl:if>
        </xsl:copy>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>
  
  <xsl:variable name="figureset">
    <xsl:for-each select="//*[contains (@class, ' topic/fig ')][*[contains(@class, ' topic/title ' )]]">
      <xsl:if test="dita-ot:notExcludedByDraftElement(.)">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:if test="not(@id)">
            <xsl:attribute name="id">
              <xsl:call-template name="get-id"/>
            </xsl:attribute>
          </xsl:if>
        </xsl:copy>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>
  
  
  <!--   LOT   -->
  
  <xsl:template match="ot-placeholder:tablelist" name="createTableList">
    <xsl:if test="//*[contains(@class, ' topic/table ')]/*[contains(@class, ' topic/title ' )]">
      <!--exists tables with titles-->
      <fo:page-sequence master-reference="toc-sequence" xsl:use-attribute-sets="page-sequence.lot">
        <xsl:call-template name="insertTocStaticContents"/>
        <fo:flow flow-name="xsl-region-body">
          <fo:block start-indent="0in">
            <xsl:call-template name="createLOTHeader"/>
            
            <xsl:apply-templates select="//*[contains (@class, ' topic/table ')]
                                            [child::*[contains(@class, ' topic/title ' )]]
                                            [dita-ot:notExcludedByDraftElement(.)]"
                                 mode="list.of.tables"/>
          </fo:block>
        </fo:flow>
        
      </fo:page-sequence>
    </xsl:if>
  </xsl:template>

  <xsl:template name="createLOTHeader">
    <fo:block xsl:use-attribute-sets="__lotf__heading" id="{$id.lot}">
      <fo:marker marker-class-name="current-header">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'List of Tables'"/>
        </xsl:call-template>
      </fo:marker>
      <xsl:apply-templates select="." mode="customTopicMarker"/>
      <xsl:apply-templates select="." mode="customTopicAnchor"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'List of Tables'"/>
      </xsl:call-template>
    </fo:block>
  </xsl:template>
  
  <xsl:template match="*[contains (@class, ' topic/table ')][child::*[contains(@class, ' topic/title ' )]]" mode="list.of.tables">

    <fo:block xsl:use-attribute-sets="__lotf__indent">
      <fo:block xsl:use-attribute-sets="__lotf__content">
        <fo:basic-link xsl:use-attribute-sets="__toc__link">
          <xsl:attribute name="internal-destination">
            <xsl:call-template name="get-id"/>
          </xsl:attribute>

          <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]/revprop[@changebar]" mode="changebar">
            <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
          </xsl:apply-templates>
          
          <fo:inline xsl:use-attribute-sets="__lotf__title">
            <xsl:call-template name="getVariable">
              <xsl:with-param name="id" select="'Table.title'"/>
              <xsl:with-param name="params">
                <number>
                  <xsl:variable name="id">
                    <xsl:call-template name="get-id"/>
                  </xsl:variable>
                  <xsl:variable name="tableNumber">
                    <xsl:number format="1" value="count($tableset/*[@id = $id]/preceding-sibling::*) + 1" />
                  </xsl:variable>
                  <xsl:value-of select="$tableNumber"/>
                </number>
                <title>
                  <xsl:apply-templates select="./*[contains(@class, ' topic/title ')]" mode="insert-text"/>
                </title>
              </xsl:with-param>
            </xsl:call-template>
          </fo:inline>
          
          <fo:inline xsl:use-attribute-sets="__lotf__page-number">
            <fo:leader xsl:use-attribute-sets="__lotf__leader"/>
            <fo:page-number-citation>
              <xsl:attribute name="ref-id">
                <xsl:call-template name="get-id"/>
              </xsl:attribute>
            </fo:page-number-citation>
          </fo:inline>

          <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]/revprop[@changebar]" mode="changebar">
            <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
          </xsl:apply-templates>
          
        </fo:basic-link>
      </fo:block>
    </fo:block>
  </xsl:template>

  <!--   LOF   -->
  
  <xsl:template match="ot-placeholder:figurelist" name="createFigureList">
      <xsl:if test="//*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ' )]">
        <!--exists figures with titles-->
        <fo:page-sequence master-reference="toc-sequence" xsl:use-attribute-sets="page-sequence.lof">

          <xsl:call-template name="insertTocStaticContents"/>
          <fo:flow flow-name="xsl-region-body">
            <fo:block start-indent="0in">
              <xsl:call-template name="createLOFHeader"/>

              <xsl:apply-templates select="//*[contains (@class, ' topic/fig ')]
                                              [child::*[contains(@class, ' topic/title ' )]]
                                              [dita-ot:notExcludedByDraftElement(.)]"
                                   mode="list.of.figures"/>
            </fo:block>
          </fo:flow>

        </fo:page-sequence>
      </xsl:if>
  </xsl:template>
  
  <xsl:template name="createLOFHeader">
    <fo:block xsl:use-attribute-sets="__lotf__heading" id="{$id.lof}">
      <fo:marker marker-class-name="current-header">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'List of Figures'"/>
        </xsl:call-template>
      </fo:marker>
      <xsl:apply-templates select="." mode="customTopicMarker"/>
      <xsl:apply-templates select="." mode="customTopicAnchor"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'List of Figures'"/>
      </xsl:call-template>
    </fo:block>
  </xsl:template>
  
  <xsl:template match="*[contains (@class, ' topic/fig ')][child::*[contains(@class, ' topic/title ' )]]" mode="list.of.figures">
    
    <fo:block xsl:use-attribute-sets="__lotf__indent">
      <fo:block xsl:use-attribute-sets="__lotf__content">
        <fo:basic-link xsl:use-attribute-sets="__toc__link">
          <xsl:attribute name="internal-destination">
            <xsl:call-template name="get-id"/>
          </xsl:attribute>

          <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]/revprop[@changebar]" mode="changebar">
            <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
          </xsl:apply-templates>
          
          <fo:inline xsl:use-attribute-sets="__lotf__title">
            <xsl:call-template name="getVariable">
              <xsl:with-param name="id" select="'Figure.title'"/>
              <xsl:with-param name="params">
                <number>
                  <xsl:variable name="id">
                    <xsl:call-template name="get-id"/>
                  </xsl:variable>
                  <xsl:variable name="figureNumber">
                    <xsl:number format="1" value="count($figureset/*[@id = $id]/preceding-sibling::*) + 1" />
                  </xsl:variable>
                  <xsl:value-of select="$figureNumber"/>
                </number>
                <title>
                  <xsl:apply-templates select="./*[contains(@class, ' topic/title ')]" mode="insert-text"/>
                </title>
              </xsl:with-param>
            </xsl:call-template>
          </fo:inline>
          
          <fo:inline xsl:use-attribute-sets="__lotf__page-number">
            <fo:leader xsl:use-attribute-sets="__lotf__leader"/>
            <fo:page-number-citation>
              <xsl:attribute name="ref-id">
                <xsl:call-template name="get-id"/>
              </xsl:attribute>
            </fo:page-number-citation>
          </fo:inline>

          <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]/revprop[@changebar]" mode="changebar">
            <xsl:with-param name="changebar-id" select="concat(dita-ot:generate-changebar-id(.),'-toc')"/>
          </xsl:apply-templates>
          
        </fo:basic-link>
      </fo:block>
    </fo:block>
  </xsl:template>

</xsl:stylesheet>
