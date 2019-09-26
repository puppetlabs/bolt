<?xml version="1.0" encoding="UTF-8" ?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
    xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
    xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="related-links dita2html ditamsg xs">

    <!-- Determines whether to generate titles for task sections. Values are YES and NO. -->
    <xsl:param name="GENERATE-TASK-LABELS" select="'YES'"/>

    <!-- Remove task labels from all task subclasses except prereq. -->
    <xsl:template match="*[contains(@class,' task/context ')]" mode="generate-task-label"/>
    <xsl:template match="*[contains(@class,' task/steps ')]" mode="generate-task-label"/>
    <xsl:template match="*[contains(@class,' task/result ')]" mode="generate-task-label"/>
    <xsl:template match="*[contains(@class,' task/postreq ')]" mode="generate-task-label"/>
    <xsl:template match="*[contains(@class,' task/taskbody ')]" mode="generate-task-label"/>
    <!-- KLL 25-May-2018: Remove label from unordered steps -->
    <xsl:template match="*[contains(@class,' task/steps-unordered ')]" mode="generate-task-label"/>


    <!-- Specialize prereq labels. -->
    <xsl:template match="*[contains(@class,' task/prereq ')]" mode="generate-task-label">
        <xsl:param name="use-label"/>
        <xsl:if test="$GENERATE-TASK-LABELS='YES'">
            <div class="tasklabel">
                <xsl:attribute name="class">tasklabeltitle tasklabel</xsl:attribute>
                <xsl:value-of select="$use-label"/>
            </div>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
