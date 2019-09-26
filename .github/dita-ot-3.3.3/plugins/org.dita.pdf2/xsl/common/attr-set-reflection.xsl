<?xml version='1.0'?>

<!-- 
Copyright © 2004-2005 by Idiom Technologies, Inc. All rights reserved. 
IDIOM is a registered trademark of Idiom Technologies, Inc. and WORLDSERVER
and WORLDSTART are trademarks of Idiom Technologies, Inc. All other 
trademarks are the property of their respective owners. 

IDIOM TECHNOLOGIES, INC. IS DELIVERING THE SOFTWARE "AS IS," WITH 
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF 
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING 
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF IDIOM
TECHNOLOGIES, INC. HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. 

Idiom Technologies, Inc. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Idiom Technologies, Inc.'s
liability for any damages hereunder exceed the amounts received by Idiom
Technologies, Inc. as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project.
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version='2.0'>

<!--
A word of explanation:
The templates in this file are to work around a problem in XSLT.  XSLT
requires that attribute sets be addressed by name, and not by a variable.

There are a few places that the plugin generates the name of an attribute
set, and wants to use it anyway.  The original version of these templates
provided a very incomplete substitute for standard attribute sets, in that
they didn't allow any XSLT constructions within the attributes, and they
didn't find attribute sets imported by the custom files.

The current version now falls back to the old implementation, but first
checks a list of possible attribute-sets, and uses attribute-sets on the
list just like regular named attribute sets.
--> 

    <xsl:template name="new-attr-set-reflection">
        <xsl:param name="temp-element" />
        <xsl:for-each select="$temp-element//@*">
            <xsl:attribute name="{name()}">
                <xsl:value-of select="."/>
            </xsl:attribute>
        </xsl:for-each>
    </xsl:template>


    <xsl:template name="processAttrSetReflection">
        <xsl:param name="attrSet"/>
        <xsl:param name="path"/>
        <xsl:choose>
            <xsl:when test="$attrSet = 'topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.topic.topic.title'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.topic.topic.title"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__tableframe__bottom'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__tableframe__bottom"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__tableframe__right'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__tableframe__right"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__tableframe__top'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__tableframe__top"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'lq'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="lq"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'lq_simple'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="lq_simple"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'table__tableframe__all'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="table__tableframe__all"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'table__tableframe__bottom'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="table__tableframe__bottom"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'table__tableframe__sides'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="table__tableframe__sides"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'table__tableframe__top'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="table__tableframe__top"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'table__tableframe__topbot'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="table__tableframe__topbot"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'thead__tableframe__bottom'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="thead__tableframe__bottom"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__align__left'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__align__left"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__align__right'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__align__right"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__align__center'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__align__center"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = '__align__justify'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="__align__justify"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'thead.row'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="thead.row"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'thead.row.entry'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="thead.row.entry"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'thead.row.entry__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="thead.row.entry__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tfoot.row'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tfoot.row"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tfoot.row.entry'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tfoot.row.entry"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tfoot.row.entry__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tfoot.row.entry__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tbody.row'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tbody.row"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tbody.row.entry'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tbody.row.entry"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'tbody.row.entry__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="tbody.row.entry__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="$attrSet = 'topic.topic.topic.topic.topic.topic.title__content'">
                <xsl:call-template name="new-attr-set-reflection">
                    <xsl:with-param name="temp-element">
                        <xsl:element name="placeholder" use-attribute-sets="topic.topic.topic.topic.topic.topic.title__content"/>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="doc-available('cfg:fo/attrs/custom.xsl') and document('cfg:fo/attrs/custom.xsl')//xsl:attribute-set[@name = $attrSet]">
                <xsl:apply-templates select="document('cfg:fo/attrs/custom.xsl')//xsl:attribute-set[@name = $attrSet]"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="document($path)//xsl:attribute-set[@name = $attrSet]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="xsl:attribute-set">

        <xsl:if test="@use-attribute-sets">
            <xsl:call-template name="processNestedAttrSets">
                <xsl:with-param name="setNames" select="normalize-space(@use-attribute-sets)"/>
            </xsl:call-template>
        </xsl:if>

        <xsl:for-each select="xsl:attribute">
            <xsl:attribute name="{@name}">
                <xsl:value-of select="."/>
            </xsl:attribute>
            <xsl:for-each select="xsl:*">
              <xsl:call-template name="output-message">
                <xsl:with-param name="id" select="'PDFX009E'"/>
                <xsl:with-param name="msgparams">%1=<xsl:value-of select="name()"/></xsl:with-param>
              </xsl:call-template>
            </xsl:for-each>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="processNestedAttrSets">
        <xsl:param name="setNames"/>
        <xsl:choose>
            <xsl:when test="contains($setNames, ' ')">
                <xsl:apply-templates select="//xsl:attribute-set[@name = substring-before($setNames, ' ')]"/>
                <xsl:call-template name="processNestedAttrSets">
                    <xsl:with-param name="setNames" select="substring-after($setNames, ' ')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="//xsl:attribute-set[@name = $setNames]"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>