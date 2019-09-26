<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2013 Eero Helenius

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    version="2.0">

    <xsl:template match="*[contains(@class,' ut-d/imagemap ')]">
        <xsl:variable name="attributes" as="attribute()*"><xsl:call-template name="commonattributes"/></xsl:variable>
        <xsl:if test="exists($attributes)">
            <fo:inline><xsl:sequence select="$attributes"/></fo:inline>
        </xsl:if>
        <xsl:apply-templates select="*[contains(@class,' topic/image ')]"/>
        <fo:list-block xsl:use-attribute-sets="ol">
            <xsl:apply-templates select="*[contains(@class,' ut-d/area ')]"/>
        </fo:list-block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' ut-d/area ')]">
        <fo:list-item xsl:use-attribute-sets="ol.li">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="ol.li__label">
                <fo:block xsl:use-attribute-sets="ol.li__label__content">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Ordered List Number'"/>
                        <xsl:with-param name="params">
                            <number>
                                <xsl:number/>
                            </number>
                        </xsl:with-param>
                    </xsl:call-template>
                </fo:block>
            </fo:list-item-label>

            <fo:list-item-body xsl:use-attribute-sets="ol.li__body">
                <fo:block xsl:use-attribute-sets="ol.li__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>

        </fo:list-item>
    </xsl:template>

    <xsl:template match="*[contains(@class,' ut-d/shape ')]"/>

    <xsl:template match="*[contains(@class,' ut-d/coords ')]"/>
</xsl:stylesheet>
