/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2017 Jarno Elovirta
 *
 *  See the accompanying LICENSE file for applicable license.
 */
package org.dita.dost.module;

import org.dita.dost.TestUtils;
import org.dita.dost.exception.DITAOTException;
import org.dita.dost.pipeline.AbstractPipelineInput;
import org.dita.dost.pipeline.PipelineHashIO;
import org.dita.dost.util.Job;
import org.dita.dost.util.Job.FileInfo.Builder;
import org.dita.dost.writer.EclipseIndexWriter;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import java.io.File;
import java.io.IOException;
import java.net.URI;

import static java.net.URI.create;
import static org.apache.commons.io.FileUtils.copyFile;
import static org.dita.dost.TestUtils.assertXMLEqual;
import static org.dita.dost.util.Constants.*;

public class IndexTermExtractModuleTest {

    private static final File resourceDir = TestUtils.getResourceDir(IndexTermExtractModuleTest.class);
    private static final File srcDir = new File(resourceDir, "src");
    private static final File expDir = new File(resourceDir, "exp");
    private static File tempDir;

    @BeforeClass
    public static void setup() throws IOException {
        tempDir = TestUtils.createTempDir(IndexTermExtractModuleTest.class);
        copyFile(new File(srcDir, "bookmap.ditamap"),
                new File(tempDir, "bookmap.ditamap"));
        copyFile(new File(srcDir, "index-see_testdata1.dita"),
                new File(tempDir, "index-see_testdata1.dita"));
    }

    @Test
    public void testWrite() throws DITAOTException, SAXException, IOException {

        final Job job = new Job(tempDir);
        job.setProperty("uplevels", "");
        job.setInputDir(srcDir.toURI());
        job.add(new Builder()
                .uri(create("bookmap.ditamap")).format("ditamap")
                .src(new File(srcDir, "bookmap.ditamap").toURI())
                .isInput(true)
                .build());
        job.setInputMap(URI.create("bookmap.ditamap"));
        job.setInputFile(new File(srcDir, "bookmap.ditamap").toURI());
        job.add(new Builder()
                .uri(create("index-see_testdata1.dita")).format("dita")
                .build());

        final IndexTermExtractModule filter = new IndexTermExtractModule();
        filter.setLogger(new TestUtils.TestLogger());
        filter.setJob(job);

        final AbstractPipelineInput input = new PipelineHashIO();
        input.setAttribute(ANT_INVOKER_EXT_PARAM_OUTPUTDIR, new File(tempDir, "out").getAbsolutePath());
        input.setAttribute(ANT_INVOKER_EXT_PARAM_OUTPUT, new File(tempDir, "input.xml").getAbsolutePath());
        input.setAttribute(ANT_INVOKER_EXT_PARAM_INDEXCLASS, EclipseIndexWriter.class.getCanonicalName());
        input.setAttribute(ANT_INVOKER_EXT_PARAM_TARGETEXT, ".html");
        filter.execute(input);

        assertXMLEqual(new InputSource(new File(expDir, "index.xml").toURI().toString()),
                new InputSource(new File(tempDir, "index.xml").toURI().toString()));
    }

    @AfterClass
    public static void teardown() throws IOException {
        TestUtils.forceDelete(tempDir);
    }

}
